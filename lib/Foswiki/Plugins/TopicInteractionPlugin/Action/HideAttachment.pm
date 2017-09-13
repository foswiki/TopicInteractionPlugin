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

package Foswiki::Plugins::TopicInteractionPlugin::Action::HideAttachment;

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');
use constant DRY => 0; # toggle me

sub handle {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response);
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', $wikiName, undef, $topic, $web)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  # disable dbcache handler during loop
  my $dbCacheEnabled = Foswiki::Func::getContext()->{DBCachePluginEnabled};
  if ($dbCacheEnabled) {
    require Foswiki::Plugins::DBCachePlugin;
    Foswiki::Plugins::DBCachePlugin::disableRenameHandler();
  }

  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  my $error;
  my $thumbnail;
  foreach my $fileName (@{$params->{filenames}}) {
    next unless $fileName;
    $fileName = $this->sanitizeAttachmentName($fileName);

    my $attachment = $meta->get("FILEATTACHMENT", $fileName);
    unless ($attachment) {
      $this->printJSONRPC($response, 102, "Attachment $fileName does not exist", $id);
      return;
    }

    my %attrs = map {$_ => 1} split(//, ($attachment->{attr} || ''));
    next if $attrs{h}; # already hidden

    $this->writeDebug("hiding fileName=$fileName, web=$web, topic=$topic");

    try {
      unless (DRY) {
        $error = Foswiki::Func::saveAttachment(
          $web, $topic, $fileName, {
            dontlog     => !$Foswiki::cfg{Log}{upload},
            hide        => 1,
          });

      }
    } catch Error::Simple with {
      $error = shift->{-text};
      $this->writeDebug("ERROR: $error");
    };

    last if $error;

    $thumbnail = $fileName if $attrs{t};
  }
  ($meta) = Foswiki::Func::readTopic($web, $topic);
  $this->setThumbnail($meta, $thumbnail) if $thumbnail && !DRY;

  if ($dbCacheEnabled) {
    # enabling dbcache handlers again
    Foswiki::Plugins::DBCachePlugin::enableRenameHandler();

    # manually update this topic
    Foswiki::Plugins::DBCachePlugin::loadTopic($web, $topic);
  }

  if ($error) {
    $this->printJSONRPC($response, 1, $error, $id);
  } else {
    $this->printJSONRPC($response, 0, undef, $id);
  }
}

1;

