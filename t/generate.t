use Docker::File;
use Test;

is
    Docker::File.new(
        images => [
            Docker::File::Image.new(
                from-short => 'ubuntu'
            )
        ]
    ),
    q:to/EXPECTED/, 'simple file with FROM';
        FROM ubuntu
        EXPECTED

is
    Docker::File.new(
        images => [
            Docker::File::Image.new(
                from-short => 'ubuntu',
                from-tag => 'latest'
            )
        ]
    ),
    q:to/EXPECTED/, 'simple file with FROM with tag';
        FROM ubuntu:latest
        EXPECTED

is
    Docker::File.new(
        images => [
            Docker::File::Image.new(
                from-short => 'ubuntu',
                from-digest => 'sha256:cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf'
            )
        ]
    ),
    q:to/EXPECTED/, 'simple file with FROM with digest';
        FROM ubuntu@sha256:cbbf2f9a99b47fc460d422812b6a5adff7dfee951d8fa2e4a98caa0382cfbdbf
        EXPECTED

sub simple-image(Docker::File::Instruction $ins) {
    Docker::File.new(
        images => [
            Docker::File::Image.new(
                from-short => 'ubuntu',
                entries => [$ins]
            )
        ]
    )
}

is
    simple-image(Docker::File::Maintainer.new(name => 'Jonathan <jnthn@jnthn.net>')),
    q:to/EXPECTED/, 'MAINTAINER';
        FROM ubuntu
        MAINTAINER Jonathan <jnthn@jnthn.net>
        EXPECTED

is
    simple-image(Docker::File::RunShell.new(command => 'sudo apt-get install perl6')),
    q:to/EXPECTED/, 'RUN (shell)';
        FROM ubuntu
        RUN sudo apt-get install perl6
        EXPECTED

is
    simple-image(Docker::File::RunExec.new(args => <sudo apt-get install perl6>)),
    q:to/EXPECTED/, 'RUN (exec)';
        FROM ubuntu
        RUN ["sudo", "apt-get", "install", "perl6"]
        EXPECTED

is
    simple-image(Docker::File::RunExec.new(
        args => ['"quoted"', "with\newline", "and \\slash"])),
    q:to/EXPECTED/, 'RUN (exec, quotes/escaping)';
        FROM ubuntu
        RUN ["\"quoted\"", "with\newline", "and \\\\slash"]
        EXPECTED

is
    simple-image(Docker::File::CommandShell.new(command => 'perl6 app.p6')),
    q:to/EXPECTED/, 'CMD (shell)';
        FROM ubuntu
        CMD perl6 app.p6
        EXPECTED

is
    simple-image(Docker::File::CommandExec.new(args => <perl6 app.p6>)),
    q:to/EXPECTED/, 'CMD (exec)';
        FROM ubuntu
        CMD ["perl6", "app.p6"]
        EXPECTED

is
    simple-image(Docker::File::CommandExec.new(
        args => ['"quoted"', "with\newline", "and \\slash"])),
    q:to/EXPECTED/, 'CMD (exec, quotes/escaping)';
        FROM ubuntu
        CMD ["\"quoted\"", "with\newline", "and \\\\slash"]
        EXPECTED

is
    simple-image(Docker::File::EntryPointShell.new(command => 'perl6 app.p6')),
    q:to/EXPECTED/, 'ENTRYPOINT (shell)';
        FROM ubuntu
        ENTRYPOINT perl6 app.p6
        EXPECTED

is
    simple-image(Docker::File::EntryPointExec.new(args => <perl6 app.p6>)),
    q:to/EXPECTED/, 'ENTRYPOINT (exec)';
        FROM ubuntu
        ENTRYPOINT ["perl6", "app.p6"]
        EXPECTED

is
    simple-image(Docker::File::EntryPointExec.new(
        args => ['"quoted"', "with\newline", "and \\slash"])),
    q:to/EXPECTED/, 'ENTRYPOINT (exec, quotes/escaping)';
        FROM ubuntu
        ENTRYPOINT ["\"quoted\"", "with\newline", "and \\\\slash"]
        EXPECTED

is
    simple-image(Docker::File::User.new(username => 'daemon')),
    q:to/EXPECTED/, 'USER';
        FROM ubuntu
        USER daemon
        EXPECTED

is
    simple-image(Docker::File::WorkDir.new(dir => '/var/lol')),
    q:to/EXPECTED/, 'WORKDIR';
        FROM ubuntu
        WORKDIR /var/lol
        EXPECTED

is
    simple-image(Docker::File::StopSignal.new(signal => 9)),
    q:to/EXPECTED/, 'STOPSIGNAL (integer)';
    FROM ubuntu
    STOPSIGNAL 9
    EXPECTED

is
    simple-image(Docker::File::StopSignal.new(signal => 'SIGKILL')),
    q:to/EXPECTED/, 'STOPSIGNAL (name)';
    FROM ubuntu
    STOPSIGNAL SIGKILL
    EXPECTED

done-testing;
