# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2014 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Action::CreateLinks;

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::Plugins::TopicInteractionPlugin::Core ();
use constant DRY => 0; # toggle me

sub handle {
  my ($response, $params) = @_;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  # disable dbcache handler during loop
  my $dbCacheEnabled = Foswiki::Func::getContext()->{DBCachePluginEnabled};
  if ($dbCacheEnabled) {
    require Foswiki::Plugins::DBCachePlugin;
    Foswiki::Plugins::DBCachePlugin::disableRenameHandler();
  }

  my $error;
  foreach my $fileName (@{$params->{filenames}}) {
    next unless $fileName;
    $fileName = Foswiki::Plugins::TopicInteractionPlugin::Core::sanitizeAttachmentName($fileName);

    if (!Foswiki::Func::attachmentExists($web, $topic, $fileName)) {
      Foswiki::Plugins::TopicInteractionPlugin::Core::printJSONRPC($response, 104, "Attachment $fileName does not exist", $id);
      return;
    }

    Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("createlink fileName=$fileName, web=$web, topic=$topic");

    my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);

    try {
      unless (DRY) {
        my $session = $Foswiki::Plugins::SESSION;
        $text = '' unless defined $text;
        $text .= $session->attach->getAttachmentLink($meta, $fileName);
        $meta->text($text);
        $meta->save();
      }
    } catch Error::Simple with {
      $error = shift->{-text};
      Foswiki::Plugins::TopicInteractionPlugin::Core::writeDebug("ERROR: $error");
    };

    last if $error;
  }

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

