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

done-testing;