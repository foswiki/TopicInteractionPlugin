# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2018 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Sandbox ();
use Foswiki::Plugins ();
use JSON ();

use constant TRACE => 0; # toggle me

# Error codes for json-rpc response
# -32601: unknown action
# -32600: method not allowed
# 0: ok
# 1: unknown error
# 100: no transaction id
# 101: topic does not exist
# 102: access denied
# 103: no filename
# 104: attachment does not exist
# 105: topic locked
# 106: error while addign file to download archiving
# 107: error while creating download archiving
# 108: won't copy attachment to itself
# 109: oversized upload
# 110: stream not found for file
# 111: zero-sized file upload

##############################################################################
sub new {
  my $class = shift;
  my $session = shift;

  $session ||= $Foswiki::Plugins::SESSION,

  my $this = bless({
      session => $session,
      prefs => {
        officeSuite => Foswiki::Func::getPreferencesValue("WEBDAV_OFFICE_SUITE") || $Foswiki::cfg{TopicInteractionPlugin}{DefaultOfficeSuite} || '',
        attachFileSizeLimit => Foswiki::Func::getPreferencesValue("ATTACHFILESIZELIMIT") || 0,
      },
      @_,
    },
    $class
  );

  # export configuration to javascript 
  my $content = "<script class='\$zone \$id foswikiPreferences' type='text/json'>{\"TopicInteractionPlugin\":" . JSON::encode_json($this->{prefs}) . "}</script>";
  Foswiki::Func::addToZone("script", "JQUERYPLUGIN::UPLOADER::META", $content, "JQUERYPLUGIN::FOSWIKI::PREFERENCES");

  return $this;
}

##############################################################################
sub restChangeProperties {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::ChangeProperties;

  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::ChangeProperties->new();
  $action->handle($response);

  $this->deleteAttachmentArchives($action->{params}{web}, $action->{params}{topic}) if $action->{params};

  return;
}

##############################################################################
sub restDelete {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::DeleteAttachment;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::DeleteAttachment->new();
  $action->handle($response);

  $this->deleteAttachmentArchives($action->{params}{web}, $action->{params}{topic}) if $action->{params};

  return;
}

##############################################################################
sub restMove {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::MoveAttachment->new();
  $action->handle($response);

  $this->deleteAttachmentArchives($action->{params}{web}, $action->{params}{topic}) if $action->{params};

  return;
}

##############################################################################
sub restUpload {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::UploadAttachment;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::UploadAttachment->new();
  $action->handle($response);

  $this->deleteAttachmentArchives($action->{params}{web}, $action->{params}{topic}) if $action->{params};

  return;
}

##############################################################################
sub restCreateLink {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::CreateLinks;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::CreateLinks->new();
  $action->handle($response);

  return;
}

##############################################################################
sub restCreateImageGallery {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::CreateImageGallery;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::CreateImageGallery->new();
  $action->handle($response);

  return;
}

##############################################################################
sub restDownload {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::DownloadAttachment;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::DownloadAttachment->new();
  $action->handle($response);

  return;
}

##############################################################################
sub restHide {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::HideAttachment;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::HideAttachment->new();
  $action->handle($response);

  return;
}

##############################################################################
sub restUnhide {
  my ($this, $subject, $verb, $response) = @_;
  
  require Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment;
  my $action = Foswiki::Plugins::TopicInteractionPlugin::Action::UnhideAttachment->new();
  $action->handle($response);

  return;
}

##############################################################################
sub deleteAttachmentArchives {
  my ($this, $web, $topic) = @_;

  return unless $web && $topic;

  my $dir = "$Foswiki::cfg{PubDir}/$web/$topic";
  my $dh;

  opendir($dh, $dir) || return;
  my @zips = grep { /^Attachments-$web-$topic-.*zip$/ } readdir($dh);
  closedir($dh);

  unless (@zips) {
    #$this->writeDebug("no archives to be cleaned up");
    return;
  }

  foreach my $zip (@zips) {
    if (defined(&Foswiki::Sandbox::validateAttachmentName)) {
      $zip = Foswiki::Sandbox::untaint($zip, \&Foswiki::Sandbox::validateAttachmentName);
    } else {
      $zip = Foswiki::Sandbox::normalizeFileName($zip);
    }
    my $zipFile = $dir . '/' . $zip;
    $this->writeDebug("deleting zip archive $zipFile");
    unlink $zipFile if -e $zipFile;
  }
}

##############################################################################
sub writeDebug {
  my $this = shift;
  print STDERR "- TopicInteractionPlugin - $_[0]\n" if TRACE;
}


1;
