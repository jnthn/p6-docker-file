use Docker::File;
use Test;

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].from, 'ubuntu', 'Correct .from';
    is $file.images[0].from-short, 'ubuntu', 'Correct .from-short';
    is $file.images[0].instructions.elems, 0, 'No instructions';
}, 'File with only FROM';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu:latest
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].from, 'ubuntu:latest', 'Correct .from';
    is $file.images[0].from-short, 'ubuntu', 'Correct .from-short';
    is $file.images[0].from-tag, 'latest', 'Correct .from-tag';
    is $file.images[0].instructions.elems, 0, 'No instructions';
}, 'FROM with tag';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu@sha256:cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].from, 'ubuntu@sha256:cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf', 'Correct .from';
    is $file.images[0].from-short, 'ubuntu', 'Correct .from-short';
    is $file.images[0].from-digest, 'sha256:cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf', 'Correct .from-digest';
    is $file.images[0].instructions.elems, 0, 'No instructions';
}, 'FROM with digest';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ouruser/sinatra
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].from, 'ouruser/sinatra', 'Correct .from';
    is $file.images[0].from-short, 'ouruser/sinatra', 'Correct .from-short';
    is $file.images[0].instructions.elems, 0, 'No instructions';
}, 'FROM with / in name';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        MAINTAINER Jonathan Worthington <jnthn@jnthn.net>
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::Maintainer, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::MAINTAINER, 'Correct instruction';
    is $ins.name, 'Jonathan Worthington <jnthn@jnthn.net>', 'Correct name property';
}, 'MAINTAINER instruction';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        RUN apt-get install mysql
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::RunShell, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::RUN, 'Correct instruction';
    is $ins.command, 'apt-get install mysql', 'Correct command';
}, 'RUN instruction, shell form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        RUN apt-get \
            install\
        mysql
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::RunShell, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::RUN, 'Correct instruction';
    is $ins.command.subst(/' '+/, ' ', :g), 'apt-get install mysql', 'Correct command';
}, 'RUN instruction, shell form multi-line';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        RUN ["apt-get", "install", "mysql"]
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::RunExec, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::RUN, 'Correct instruction';
    is $ins.args, <apt-get install mysql>, 'Correct args';
}, 'RUN instruction, exec form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        RUN [ "apt-get", "install" , "mysql"  ]
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::RunExec, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::RUN, 'Correct instruction';
    is $ins.args, <apt-get install mysql>, 'Correct args';
}, 'RUN instruction, exec form, odd whitespace';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        CMD echo "This is a test." | wc -
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::CommandShell, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::CMD, 'Correct instruction';
    is $ins.command, 'echo "This is a test." | wc -', 'Correct command';
}, 'CMD instruction, shell form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        CMD echo "This is a\
        test." | wc -
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::CommandShell, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::CMD, 'Correct instruction';
    is $ins.command, 'echo "This is a test." | wc -', 'Correct command';
}, 'CMD instruction, shell form multi-line';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        CMD ["/usr/bin/wc","--help"]
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::CommandExec, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::CMD, 'Correct instruction';
    is $ins.args, </usr/bin/wc --help>, 'Correct args';
}, 'CMD instruction, exec form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        ENTRYPOINT exec top -b
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::EntryPointShell, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::ENTRYPOINT, 'Correct instruction';
    is $ins.command, 'exec top -b', 'Correct command';
}, 'ENTRYPOINT instruction, shell form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        ENTRYPOINT exec\
        top -b
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::EntryPointShell, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::ENTRYPOINT, 'Correct instruction';
    is $ins.command, 'exec top -b', 'Correct command';
}, 'ENTRYPOINT instruction, shell form multi-line';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::EntryPointExec, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::ENTRYPOINT, 'Correct instruction';
    is $ins.args, </usr/sbin/apache2ctl -D FOREGROUND>, 'Correct args';
}, 'ENTRYPOINT instruction, exec form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::EntryPointExec, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::ENTRYPOINT, 'Correct instruction';
    is $ins.args, </usr/sbin/apache2ctl -D FOREGROUND>, 'Correct args';
}, 'ENTRYPOINT instruction, exec form';

subtest {
    my $file = Docker::File.parse: q:to/DOCKER/;
        FROM ubuntu
        USER daemon
        DOCKER
    is $file.images.elems, 1, 'Parsed successfully';
    is $file.images[0].instructions.elems, 1, '1 instruction';
    my $ins = $file.images[0].instructions[0];
    isa-ok $ins, Docker::File::User, 'Correct type';
    is $ins.instruction, Docker::File::InstructionName::USER, 'Correct instruction';
    is $ins.username, 'daemon', 'Correct username';
}, 'USER instruction';

done-testing;
