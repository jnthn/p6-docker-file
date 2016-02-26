class X::Docker::File::TagAndDigest is Exception {
    method message() { "FROM cannot have both a tag and a digest" }
}

class X::Docker::File::OnBuild is Exception {
    has $.bad-instruction;
    method message() { "ONBUILD may not be used with '$!bad-instruction'" }
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

    subset SignalIdentifier where -> $sig {
        $sig ~~ Int ||
        $sig ~~ Str && $sig ~~ /^SIG\w+$/
    }

    class StopSignal does Instruction[STOPSIGNAL] {
        has SignalIdentifier $.signal;
    }

    class OnBuild does Instruction[ONBUILD] {
        has Instruction $.build;
    }

    class Expose does Instruction[EXPOSE] {
        has Int @.ports;
    }

    class Add does Instruction[ADD] {
        has Str @.sources;
        has Str $.destination;
    }

    class Copy does Instruction[COPY] {
        has Str @.sources;
        has Str $.destination;
    }

    class Arg does Instruction[ARG] {
        has Str $.name;
        has Cool $.default;
    }

    class Label does Instruction[LABEL] {
        has Str %.labels;
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
            <instruction>* %% <insignificant-lines>
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

        proto token instruction { * }

        token instruction:sym<MAINTAINER> {
            <sym> \h+ $<name>=[\N+] \n
        }

        token instruction:sym<RUN> {
            <sym> \h+ <shell-or-exec('RUN')> \n
        }

        token instruction:sym<CMD> {
            <sym> \h+ <shell-or-exec('CMD')> \n
        }

        token instruction:sym<ENTRYPOINT> {
            <sym> \h+ <shell-or-exec('ENTRYPOINT')> \n
        }

        token instruction:sym<USER> {
            <sym> \h+ $<username>=[\S+] \h* \n
        }

        token instruction:sym<WORKDIR> {
            <sym> \h+ $<dir>=[\N+] \n
        }

        token instruction:sym<STOPSIGNAL> {
            <sym> \h+
            [
            | $<signum>=[\d+]
            | $<signame>=[SIG\w+]
            ] \h* \n
        }

        token instruction:sym<ONBUILD> {
            <sym> \h+
            [
            || $<bad>=< FROM MAINTAINER ONBUILD > \h
               { die X::Docker::File::OnBuild.new(bad-instruction => ~$<bad>) }
            || <instruction>
            ]
        }

        token instruction:sym<EXPOSE> {
            <sym> \h+ [$<port>=[\d+]]+ %% [\h+] \n
        }

        token instruction:sym<ADD> {
            <sym> \h+ <file-list('ADD')> \h* \n
        }

        token instruction:sym<COPY> {
            <sym> \h+ <file-list('COPY')> \h* \n
        }

        token instruction:sym<ARG> {
            <sym> \h+
            $<name>=[<-[\s=]>+] \h*
            ['=' \h* $<default>=[\N+]]?
            \n
        }

        token instruction:sym<LABEL> {
            <sym> \h+ <label>+ % [\h+ | \h* \\ \n \h*] \n
        }

        token label {
            [
            | <?["]> <key=.arg>
            | $<key>=[<-[\s"=]>+]
            ] \h* '=' \h* <value=.arg>
        }

        token shell-or-exec($instruction) {
            | <?[[]> <exec=.arglist($instruction)>
            | {} <shell=.multiline-command>
        }

        token file-list($instruction) {
            | <?[[]> <arglist($instruction)>
            | {} [$<file>=[\S+]]+ % [\h+]
        }

        token arglist($instruction) {
            || '[' \h* <arg>+ % [\h* ',' \h*] \h* ']'
            || { die "Cannot parse args to $instruction" }
        }

        token arg {
            \" ~ \" [ <str>  | \\\n | \\ <str=.str_escape> ]*
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
            my @entries = $<instruction>.map(*.made);
            my $f = $<from>;
            make Image.new(
                from-short => ~$f<name>,
                from-tag => $f<tag> ?? ~$f<tag> !! Str,
                from-digest => $f<digest> ?? ~$f<digest> !! Str,
                :@entries
            );
        }

        method instruction:sym<MAINTAINER>($/) {
            make Maintainer.new(name => ~$<name>)
        }

        method instruction:sym<RUN>($/) {
            with $<shell-or-exec><shell> {
                make RunShell.new(command => .made);
            }
            orwith $<shell-or-exec><exec> {
                make RunExec.new(args => .made);
            }
        }

        method instruction:sym<CMD>($/) {
            with $<shell-or-exec><shell> {
                make CommandShell.new(command => .made);
            }
            orwith $<shell-or-exec><exec> {
                make CommandExec.new(args => .made);
            }
        }

        method instruction:sym<ENTRYPOINT>($/) {
            with $<shell-or-exec><shell> {
                make EntryPointShell.new(command => .made);
            }
            orwith $<shell-or-exec><exec> {
                make EntryPointExec.new(args => .made);
            }
        }

        method instruction:sym<USER>($/) {
            make User.new(username => ~$<username>);
        }

        method instruction:sym<WORKDIR>($/) {
            make WorkDir.new(dir => ~$<dir>);
        }

        method instruction:sym<STOPSIGNAL>($/) {
            with $<signum> {
                make StopSignal.new(signal => +$_);
            }
            else {
                make StopSignal.new(signal => ~$<signame>);
            }
        }

        method instruction:sym<ONBUILD>($/) {
            make OnBuild.new(build => $<instruction>.made);
        }

        method instruction:sym<EXPOSE>($/) {
            make Expose.new(ports => $<port>.map(+*));
        }

        method instruction:sym<ADD>($/) {
            my @sources = $<file-list>.made;
            my $destination = @sources.pop;
            make Add.new(:@sources, :$destination);
        }

        method instruction:sym<COPY>($/) {
            my @sources = $<file-list>.made;
            my $destination = @sources.pop;
            make Copy.new(:@sources, :$destination);
        }

        method instruction:sym<ARG>($/) {
            make Arg.new(
                name => ~$<name>,
                default => $<default> ?? ~$<default> !! Str
            );
        }

        method instruction:sym<LABEL>($/) {
            make Label.new(labels => $<label>.map(*.made));
        }

        method label($/) {
            my $key = $<key>.made // ~$<key>;
            make $key => $<value>.made;
        }

        method file-list($/) {
            with $<arglist> {
                make .made;
            }
            else {
                make $<file>.map(~*);
            }
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
