# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2015 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment;

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins::TopicInteractionPlugin::Core ();
use constant DRY => 0; # toggle me

sub handle {
  my ($response, $params) = @_;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', $wikiName, undef, $topic, $web)) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 102, "Access denied", $id);
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
    $fileName = Foswiki::Plugins::TopicInteractionPlugin::Core::sanitizeAttachmentName($fileName);

    my $attachment = $meta->get("FILEATTACHMENT", $fileName);
    unless ($attachment) {
      Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 102, "Attachment $fileName does not exist", $id);
      return;
    }

    my %attrs = map {$_ => 1} split(//, ($attachment->{attr} || ''));
    next unless $attrs{h}; # not hidden

    Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("unhiding fileName=$fileName, web=$web, topic=$topic");

    try {
      unless (DRY) {
        $error = Foswiki::Func::saveAttachment(
          $web, $topic, $fileName, {
            dontlog     => !$Foswiki::cfg{Log}{upload},
            hide        => 0,
          });

      }
    } catch Error::Simple with {
      $error = shift->{-text};
      Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("ERROR: $error");
    };

    last if $error;

    $thumbnail = $fileName if $attrs{t};
  }
  ($meta) = Foswiki::Func::readTopic($web, $topic);
  Foswiki::Plugins::TopicInteractionPlugin::Core::setThumbnail($meta, $thumbnail) if $thumbnail && !DRY;

  if ($dbCacheEnabled) {
    # enabling dbcache handlers again
    Foswiki::Plugins::DBCachePlugin::enableRenameHandler();

    # manually update this topic
    Foswiki::Plugins::DBCachePlugin::loadTopic($web, $topic);
  }

  if ($error) {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 1, $error, $id);
  } else {
    Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 0, undef, $id)
  }
}

1;

