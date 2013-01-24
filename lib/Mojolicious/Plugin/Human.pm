package Mojolicious::Plugin::Human;

use strict;
use warnings;
use utf8;

use Mojo::Base 'Mojolicious::Plugin';
use Carp;

use DateTime;
use DateTime::Format::DateParse;

our $VERSION = '0.2';

=encoding utf-8

=head1 NAME

Mojolicious::Plugin::Human - Helpers to print values as human readable form.

=head1 SYNOPSIS

    $self->plugin('Human', {

        # Set money parameters if you need
        money_delim => ",",
        money_digit => " ",

        # Or change date and time strings
        datetime    => '%d.%m.%Y %H:%M',
        time        => '%H:%M:%S',
        date        => '%d.%m.%Y',
    });

=head1 DESCRIPTION

You can use this module in Mojo template engine to make you users happy.

=head1 CONFIGURATION

=over

=item money_delim

Set format for human readable delimiter of money. Default: <.>

=item money_digit

Set format for human readable digits of money. Default: <,>

=item datetime

Set format for human readable date and time. Default: %F %H:%M

=item time

Set format for human readable time. Default: %H:%M:%S

=item date

=item time

Set format for human readable date. Default: %F

=back

=head1 DATE AND TIME HELPERS

=head2 str2time

Get string, return timestamp

=head2 strftime

Get string, return formatted string

=head2 human_datetime

Get string, return date and time string in human readable form.

=head2 human_time

Get string, return time string in human readable form.

=head2 human_date

Get string, return date string in human readable form.

=head1 MONEY HELPERS

=head2 human_money

Get number, return money string in human readable form with levels.

=head1 PHONE HELPERS

=head2 human_phones

Get srtring, return phones (if many) string in human readable form.

=head2 yandex_phone

Get srtring, return just numbers phone string without country code.

=head1 TEXT HELPERS

=head2 human_suffix $str, $count, $one, $two, $many

Get word base form and add some of suffix ($one, $two, $many) depends of $count

=cut

# Compiled regexp for placement level in the money functions
my $REGEXP_DIGIT = qr{^(-?\d+)(\d{3})};

sub clean_phone($);
sub human_phone($);
sub date_parse($);

sub register {
    my ($self, $app, $conf) = @_;

    # Configuration
    $conf                 ||= {};
    $conf->{money_delim}  //= '.';
    $conf->{money_digit}  //= ',';

    $conf->{datetime}   //= '%F %H:%M';
    $conf->{time}       //= '%H:%M:%S';
    $conf->{date}       //= '%F';

    # Datetime

    $app->helper(str2time => sub {
        my ($self, $str) = @_;
        my $datetime = date_parse( $str );
        return $str unless $datetime;
        return $datetime->epoch;
    });

    $app->helper(strftime => sub {
        my ($self, $format, $str) = @_;
        return unless defined $str;
        my $datetime = date_parse( $str );
        return $str unless $datetime;
        return $datetime->strftime( $format );
    });

    $app->helper(human_datetime => sub {
        my ($self, $str) = @_;
        my $datetime = date_parse( $str );
        return $str unless $datetime;
        return $datetime->strftime($conf->{datetime});
    });

    $app->helper(human_time => sub {
        my ($self, $str) = @_;
        my $datetime = date_parse( $str );
        return $str unless $datetime;
        return $datetime->strftime($conf->{time});
    });

    $app->helper(human_date => sub {
        my ($self, $str) = @_;
        my $datetime = date_parse( $str );
        return $str unless $datetime;
        return $datetime->strftime($conf->{date});
    });

    # Money

    $app->helper(human_money => sub {
        my ($self, $str) = @_;
        return $str if !defined($str) || !length($str);
        my $delim = $conf->{money_delim};
        my $digit = $conf->{money_digit};
        $str = sprintf '%.2f', $str;
        $str =~ s{\.}{$delim};
        1 while $str =~ s{$REGEXP_DIGIT}{$1$digit$2};
        return $str;
    });

    # Phones

    $app->helper(human_phones => sub {
        my ($self, $str) = @_;
        return '' unless $str;
        my @phones = split /[\s,;:]+/, $str;
        return join ', ' => grep { $_ } map { human_phone $_ } @phones;
    });

    $app->helper(yandex_phone => sub {
        my ($self, $phone) = @_;
        return clean_phone($phone) || '';
    });

    # Text

    $app->helper(human_suffix => sub {
        my ($self, $str, $count, $one, $two, $many) = @_;

        return      unless defined $str;
        return $str unless defined $count;

        # Last digit
        my $tail = abs( $count ) % 10;

        # Default suffix
        $one  //= $str;
        $two  //= $str . 'a';
        $many //= $str . 'ов';

        # Get right suffix
        my $result =
            ( $tail == 0 )                  ?$many  :
            ( $tail == 1 )                  ?$one   :
            ( $tail >= 2  and $tail < 5 )   ?$two   :$many;

        # For 10 - 20 get special suffix
        $tail = abs( $count ) % 100;
        $result =
            ( $tail >= 10 and $tail < 21 )  ?$many  :$result;

        return $result;
    });
}

=head1 INTERNAL FUNCIONS

=head2 clean_phone

Clear phones. Fix first local digit 8 problem.

Return <undef> if phome not correct

=cut

sub clean_phone($) {
    my ($phone) = @_;
    return undef unless $phone;
    for ($phone) {
        s/\D+//g;

        $_ = '495' . $_ if 7 == length;

        return undef unless 10 <= length $phone;

        if (11 == length $_) { # have a country code
            s/^8/7/;
        } elsif (10 == length $_) { # havn`t country code
            s/^/7/;
        }

        s/^/+/;
    }
    return $phone;
}

=head2 human_phone

Make phone string in human readable form.

=cut

sub human_phone($) {
    my ($phone) = @_;
    $phone = clean_phone $phone;
    return $phone unless $phone;
    $phone =~ s/(...)(...)(....)$/-$1-$2-$3/;
    return $phone;
}

=head2 date_parse $str

Get a string and return DateTime or undef. Have a hack for parse Russian data
and time.

=cut

sub date_parse($) {
    my ($str) = @_;

    return unless $str;

    my $dt;

    my $tzone = DateTime::TimeZone->new( name => 'local' );

    # Take a russian date if possible
    my ($day, $month, $year, $hour, $minute, $second, $tz) =
        $str =~ m{^
            (\d{2})\.(\d{2})\.(\d{4})
            (?:
                \s+
                (\d{2}):(\d{2}):(\d{2})?(?:\.\d+)?
            )?
            (?:
                \s+
                (.*)
            )?
        $}xs;
    if( $day and $month and $year ) {
        $dt = eval {
            DateTime->new(
                year        => $year,
                month       => $month,
                day         => $day,
                hour        => $hour    || 0,
                minute      => $minute  || 0,
                second      => $second  || 0,
                time_zone   => ($tz)
                                ?DateTime::TimeZone->new( name => $tz )
                                :$tzone,
            );
        };
        return if !$dt or $@;
    } else {
        $dt = eval {
            DateTime::Format::DateParse->parse_datetime( $str, $tzone->name );
        };
        return if !$dt or $@;
    }

    return $dt;
}

1;

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
