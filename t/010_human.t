#!/usr/bin/perl

use warnings;
use strict;
use utf8;
use open qw(:std :utf8);
use lib qw(lib ../lib ../../lib);

use Test::More tests => 23;
use Encode qw(decode encode);


BEGIN {
    use_ok 'Test::Mojo';
    use_ok 'Mojolicious::Plugin::Human';
    use_ok 'DateTime';
}

{
    package MyApp;
    use Mojo::Base 'Mojolicious';

    sub startup {
        my ($self) = @_;
        $self->plugin('Human');
    }
    1;
}

my $t = Test::Mojo->new('MyApp');
ok $t, 'Test Mojo created';

$t->app->routes->post("/test/human")->to( cb => sub {
    my ($self) = @_;

    my $dt   = DateTime->from_epoch( epoch => time, time_zone  => 'local');
    my $dstr = $dt->strftime('%F %T %z');

    ok $self->str2time( $dstr ) == $dt->epoch, 'str2time';
    ok $self->strftime( '%T', $dstr ) eq $dt->strftime('%T'),
        'strftime';
    ok $self->human_datetime( $dstr ) eq $dt->strftime('%F %H:%M'),
        'human_datetime';
    ok $self->human_time( $dstr ) eq $dt->strftime('%H:%M:%S'),
        'human_time';
    ok $self->human_date( $dstr ) eq $dt->strftime('%F'),
        'human_date';

    ok !defined $self->human_money(),
        'human_money undefined';
    ok $self->human_money('') eq '',
        'human_money empty';

    ok $self->human_money('12345678.00') eq '12,345,678.00',
        'human_money';

    ok $self->human_phones('1234567890') eq '+7-123-456-7890',
        'human_phones';
    ok $self->human_phones('1234567890,0987654321')
        eq '+7-123-456-7890, +7-098-765-4321',
        'human_phones many';
    ok $self->yandex_phone('1234567890') eq '+71234567890',
        'yandex_phone';


    ok $self->human_suffix('', 0, '1','2','100500') eq '100500',
        'human_suffix 0';
    ok $self->human_suffix('', 1, '1','2','100500') eq '1',
        'human_suffix 1';
    for my $count (2..4) {
        ok $self->human_suffix('', $count, '1','2','100500') eq '2',
            "human_suffix $count";
    }
    ok $self->human_suffix('', 6, '1','2','100500') eq '100500',
        'human_suffix 6';

    $self->render(text => 'OK.');
});

$t->post_form_ok("/test/human" => {})-> status_is( 200 );

diag decode utf8 => $t->tx->res->body unless $t->tx->success;

=head1 AUTHORS

Dmitry E. Oboukhov <unera@debian.org>,
Roman V. Nikolaev <rshadow@rambler.ru>

=head1 COPYRIGHT

Copyright (C) 2011 Dmitry E. Oboukhov <unera@debian.org>
Copyright (C) 2011 Roman V. Nikolaev <rshadow@rambler.ru>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

