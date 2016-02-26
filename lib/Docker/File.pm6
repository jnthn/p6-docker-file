class X::Docker::File::TagAndDigest is Exception {
    method message() { "FROM cannot have both a tag and a digest" }
}

class Docker::File {
    enum InstructionName <
        MAINTAINER RUN CMD LABEL EXPOSE ENV ADD COPY ENTRYPOINT
        VOLUME USER WORKDIR ARG ONBUILD STOPSIGNAL
    >;

    role Entry {
    }

    class Comment does Entry {
        has Str $.text;
    }

    role Instruction[InstructionName $ins] does Entry {
        has InstructionName $.instruction = $ins;
    }

    class Maintainer does Instruction[MAINTAINER] {
        has Str $.name;
    }

    class RunShell does Instruction[RUN] {
        has Str $.command;
    }

    class RunExec does Instruction[RUN] {
        has Str @.args;
    }

    class CommandShell does Instruction[CMD] {
        has Str $.command;
    }

    class CommandExec does Instruction[CMD] {
        has Str @.args;
    }

    class EntryPointShell does Instruction[ENTRYPOINT] {
        has Str $.command;
    }

    class EntryPointExec does Instruction[ENTRYPOINT] {
        has Str @.args;
    }

    class User does Instruction[USER] {
        has Str $.username;
    }

    class WorkDir does Instruction[WORKDIR] {
        has Str $.dir;
    }

    class Image {
        has Str $.from-short;
        has Str $.from-tag;
        has Str $.from-digest;
        has Entry @.entries;

        submethod BUILD(:$!from-short, :$from-tag, :$from-digest, :@!entries) {
            if $from-tag.defined && $from-digest.defined {
                die X::Docker::File::TagAndDigest.new;
            }
            $!from-tag = $from-tag;
            $!from-digest = $from-digest;
        }

        method from() {
            with $!from-tag {
                "$!from-short:$!from-tag"
            }
            orwith $!from-digest {
                "$!from-short@$!from-digest"
            }
            else {
                $!from-short
            }
        }

        method instructions() {
            @!entries.grep(Instruction)
        }
    }

    has Image @.images;

    grammar Parser {
        rule TOP {
            <image>+
        }

        token image {
            <insignificant-lines>
            <from>
            <directive>* %% <insignificant-lines>
        }

        token from {
            'FROM'
            \h+
            <name=.gitty-name>
            [
            | ':' <tag=.gitty-name>
            | '@' $<digest>=[<[\w:]>+]
            ]?
            \h* \n
        }

        token gitty-name {
            \w <[\w/-]>+
        }

        proto token directive { * }

        token directive:sym<MAINTAINER> {
            <sym> \h+ $<name>=[\N+] \n
        }

        token directive:sym<RUN> {
            <sym> \h+ <shell-or-exec('RUN')> \n
        }

        token directive:sym<CMD> {
            <sym> \h+ <shell-or-exec('CMD')> \n
        }

        token directive:sym<ENTRYPOINT> {
            <sym> \h+ <shell-or-exec('ENTRYPOINT')> \n
        }

        token directive:sym<USER> {
            <sym> \h+ $<username>=[\S+] \h* \n
        }

        token directive:sym<WORKDIR> {
            <sym> \h+ $<dir>=[\N+] \n
        }

        token shell-or-exec($directive) {
            | <?[[]> <exec=.arglist($directive)>
            | {} <shell=.multiline-command>
        }

        token arglist($directive) {
            || '[' \h* <arg>+ % [\h* ',' \h*] \h* ']'
            || { die "Cannot parse args to $directive" }
        }

        token arg {
            \" ~ \" [ <str> | \\ <str=.str_escape> ]*
        }

        token str {
            <-["\\\t\n]>+
        }

        token str_escape {
            <["\\/bfnrt]> | 'u' <utf16_codepoint>+ % '\u'
        }

        token utf16_codepoint {
            <.xdigit>**4
        }

        token multiline-command {
            $<line>=[<-[\n\\]>+ [<!before \\ \h* \n> \\]?]+
            [ \\ \h* \n <continuation=.multiline-command> ]?
        }

        token insignificant-lines {
            [
            | <comment>
            | \h+ \n
            ]*
        }

        token comment {
            '#' \N+ \n
        }
    }

    class Actions {
        method TOP($/) {
            make Docker::File.new(images => $<image>.map(*.made));
        }

        method image($/) {
            my @entries = $<directive>.map(*.made);
            my $f = $<from>;
            make Image.new(
                from-short => ~$f<name>,
                from-tag => $f<tag> ?? ~$f<tag> !! Str,
                from-digest => $f<digest> ?? ~$f<digest> !! Str,
                :@entries
            );
        }

        method directive:sym<MAINTAINER>($/) {
            make Maintainer.new(name => ~$<name>)
        }

        method directive:sym<RUN>($/) {
            with $<shell-or-exec><shell> {
                make RunShell.new(command => .made);
            }
            orwith $<shell-or-exec><exec> {
                make RunExec.new(args => .made);
            }
        }

        method directive:sym<CMD>($/) {
            with $<shell-or-exec><shell> {
                make CommandShell.new(command => .made);
            }
            orwith $<shell-or-exec><exec> {
                make CommandExec.new(args => .made);
            }
        }

        method directive:sym<ENTRYPOINT>($/) {
            with $<shell-or-exec><shell> {
                make EntryPointShell.new(command => .made);
            }
            orwith $<shell-or-exec><exec> {
                make EntryPointExec.new(args => .made);
            }
        }

        method directive:sym<USER>($/) {
            make User.new(username => ~$<username>);
        }

        method directive:sym<WORKDIR>($/) {
            make WorkDir.new(dir => ~$<dir>);
        }

        method arglist($/) {
            make $<arg>.map(*.made);
        }

        method arg($/) {
            make +@$<str> == 1
                ?? $<str>[0].made
                !! $<str>>>.made.join;
        }

        method str($/) {
            make ~$/;
        }

        method str_escape($/) {
            if $<utf16_codepoint> {
                make utf16.new( $<utf16_codepoint>.map({:16(~$_)}) ).decode();
            } else {
                constant %escapes = hash
                    '\\' => "\\",
                    '/'  => "/",
                    'b'  => "\b",
                    'n'  => "\n",
                    't'  => "\t",
                    'f'  => "\f",
                    'r'  => "\r",
                    '"'  => "\"";
                make %escapes{~$/};
            }
        }

        method multiline-command($/) {
            with $<continuation> {
                make ~$<line> ~ ' ' ~ .made;
            }
            else {
                make ~$<line>;
            }
        }
    }

    method parse($source) {
        with Parser.parse($source, actions => Actions) {
            .made
        }
        else {
            die "Could not parse Docker file";
        }
    }

    method parsefile($file, *%slurp-options) {
        self.parse(slurp($file, |%slurp-options))
    }
}
