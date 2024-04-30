# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2024 Michael Daum, http://michaeldaumconsulting.com
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
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
use Foswiki::Plugins::ImagePlugin ();

our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');
use constant DRY => 0; # toggle me

sub handle {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response);
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};
  my $type = $params->{type} || '';
  my $doHideFile = defined($params->{hidefile})?Foswiki::Func::isTrue($params->{hidefile}, 0):undef;

  # check permissions
  my $wikiName = Foswiki::Func::getWikiName();
  unless (Foswiki::Func::checkAccessPermission(
    'CHANGE', $wikiName, undef, $topic, $web)) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  my ($oopsUrl, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);
  my $lockWikiName = Foswiki::Func::getWikiName($loginName);
  if ($unlockTime && $wikiName ne $lockWikiName) {
    $this->printJSONRPC($response, 105, "Topic is locked by $loginName", $id);
    return; 
  }

  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
  $text = '' unless defined $text;

  my $error;
  foreach my $fileName (@{$params->{filenames}}) {
    next unless $fileName;

    my $attachment = $meta->get("FILEATTACHMENT", $fileName);
    unless ($attachment) {
      $this->printJSONRPC($response, 104, "Attachment $fileName does not exist", $id);
      return;
    }

    if (defined $doHideFile) {
      my %attrs = map {$_ => 1} split(//, ($attachment->{attr} || ''));
      if ($doHideFile) {
        $attrs{h} = 1;
      } else {
        delete $attrs{h};
      }
      $attachment->{attr} = join("", sort keys %attrs);
    }

    $this->writeDebug("createlink fileName=$fileName, web=$web, topic=$topic, doHideFile=".($doHideFile//'undef').", type=$type");
    $text .= $this->getAttachmentLink($meta, $fileName, $type);
  }

  try {
    unless (DRY) {
      $meta->text($text);
      $meta->save();
    }
  } catch Error::Simple with {
    $error = shift->{-text};
    $this->writeDebug("ERROR: $error");
  };

  if ($error) {
    $this->printJSONRPC($response, 1, $error, $id);
  } else {
    $this->printJSONRPC($response, 0, undef, $id)
  }
}

sub getAttachmentLink {
  my ($this, $meta, $fileName, $type) = @_;

  my $attachment = $meta->get('FILEATTACHMENT', $fileName);
  my $fileComment = $attachment->{comment} // '';
  my $fileTime = Foswiki::Func::formatTime($attachment->{date} || 0);
  my $filePath = $Foswiki::cfg{PubDir} . '/' . $meta->web . '/' . $meta->topic . '/' . $fileName;
  my ($fileExt) = $fileName =~ m/(?:.*\.)*([^.]*)/;
  $fileExt //= '';
  my $fileUrl = Foswiki::Func::getPubUrlPath($meta->web, $meta->topic, $fileName);

  my $width = "";
  my $height = "";
  my $geom = "";

  my $format = $this->getAttachmentFormat($fileName, $type);
  return "" if $format eq "";

  # only support values if ImagePlugin is installed
  if ($format =~ /\$width|\$height|\$size/) {
    ($width, $height) = $this->ping($filePath);
    $geom = "width='$width' height='$height'";
  }

  $format =~ s/\$name/$fileName/;    # deprecated
  $format =~ s/\$filename/$fileName/g;
  $format =~ s/\$fileurl/$fileUrl/g;
  $format =~ s/\$fileext/$fileExt/;

  # SMELL: backwards compatibility ... 
  $format =~ s/\\t/\t/g;
  $format =~ s/\\n/\n/g;

  $format =~ s/\$comment/$fileComment/g;
  $format =~ s/\$size/$geom/g;

  # new
  $format =~ s/\$width/$width/g;
  $format =~ s/\$height/$height/g;
  $format =~ s/\$date/$fileTime/g;

  # this is deliberatley orderd that way to prevent some makros from being executed
  $format = Foswiki::Func::expandCommonVariables($format) if $format =~ /%/;
  $format = Foswiki::Func::decodeFormatTokens($format);

  return $format;
}

sub ping {
  my ($this, $filePath) = @_;

  return Foswiki::Plugins::ImagePlugin::getCore()->mage->Ping($filePath);
}

sub getAttachmentFormat {
  my ($this, $fileName, $type) = @_;

  my $format;
  my @prefNames = ();

  $type = $type?"_$type":"";

  if ($type ne '_file') {

    if ($fileName =~ /(?:.*\.)*([^.]*)/) {
      push @prefNames, 'ATTACHED_'.uc($1).uc($type).'_FORMAT' if $type;
      push @prefNames, 'ATTACHED_'.uc($1).'_FORMAT';
    }

    my ($mimeType) = $this->getMappedMimeType($fileName);
    if ($mimeType) {
      push @prefNames, 'ATTACHED_'.uc($mimeType).uc($type).'_FORMAT' if $type;
      push @prefNames, 'ATTACHED_'.uc($mimeType).'_FORMAT';
      
      push @prefNames, 'ATTACHEDIMAGEFORMAT' if $mimeType eq 'image';
    }
  }

  push @prefNames, 'ATTACHED_FILE'.uc($type).'_FORMAT' if $type;
  push @prefNames, 'ATTACHED_FILE_FORMAT';
  push @prefNames, 'ATTACHEDFILELINKFORMAT'; # backwards compatibility

  foreach my $prefName (@prefNames) {
    $format = Foswiki::Func::getPreferencesValue($prefName);
    last if $format;
  }

  $format = '$n   * [[$percntATTACHURLPATH{"$filename"}$percnt][$filename]]' unless defined $format;

  return $format;
}


sub types {
  my $this = shift;

  $this->{_types} = Foswiki::Func::readFile($Foswiki::cfg{MimeTypesFileName}) unless defined $this->{_types};
  $this->{_types} //= "";

  return $this->{_types};
}

sub getMimeType {
  my ($this, $fileName) = @_;

  my $mimeType;
  my $suffix = $fileName;

  if ($fileName =~ /\.([^.]+)$/) {
    $suffix = $1;
  }

  if ($this->types =~ /^([^#]\S*).*?\s$suffix(?:\s|$)/im) {
    $mimeType = $1;
  }

  return unless defined $mimeType;

  my ($type, $subType) = $mimeType =~ /^(.*)\/(.*)$/;

  return wantarray ? ($type, $subType) : $mimeType;
}

sub getMappedMimeType {
  my ($this, $fileName) = @_;

  my ($type, $subType) = $this->getMimeType($fileName);
  return unless defined $type;

  if ($type eq 'application') {
    if ($subType =~ /document|ms\-?word|ms\-?excel|rtf/) {
      $type = 'document';
    } elsif ($subType =~ /pdf|postscript/) {
      $type = 'pdf';
    } elsif ($subType =~ /xcf/) {
      $type = 'image';
    }
  }

  return wantarray ? ($type, $subType) : "$type/$subType";
}

1;

