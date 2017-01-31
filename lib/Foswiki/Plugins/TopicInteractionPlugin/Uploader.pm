# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2017 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TopicInteractionPlugin::Uploader;

use strict;
use warnings;

use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();

our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::TopicInteractionPlugin::Uploader

This is the perl stub for the jquery.uploader plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
  my $class = shift;

  my $this = bless(
    $class->SUPER::new(
      $Foswiki::Plugins::SESSION,
      name => 'Uploader',
      version => '2.00',
      author => 'Michael Daum',
      homepage => 'http://foswiki.org/Externsions/TopicInteractionPlugin',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/TopicInteractionPlugin',
      documentation => "$Foswiki::cfg{SystemWebName}.TopicInteractionPlugin",
      javascript => ['uploader.js'],
      css => ['uploader.css'],
      dependencies => ['blockui', 'scrollto', 'button', 'livequery', 'metadata', 'ui::dialog', 'pnotify', 'form', 'i18n', 'JavascriptFiles/foswikiPref'],
      i18n => $Foswiki::cfg{SystemWebName} . "/TopicInteractionPlugin/i18n",
      @_
    ),
    $class
  );

  return $this;
}

1;

