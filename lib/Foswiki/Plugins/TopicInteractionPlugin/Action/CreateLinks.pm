# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2010-2026 Michael Daum, http://michaeldaumconsulting.com
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

  my $params = $this->prepareAction($response, {requireTopic => 1, requireFileName => 1});
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

  foreach my $fileName ($this->getFileNames($meta)) {
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
    my $link = $this->getAttachmentLink($meta, $fileName, $type);

    # this is deliberatley orderd that way to prevent some makros from being executed
    $link = Foswiki::Func::expandCommonVariables($link, $topic, $web, $meta) if $link =~ /%/;
    $link = Foswiki::Func::decodeFormatTokens($link);

    # better late than never
    $link =~ s/\$text\b/$fileName/;

    $text .= "\n\n$link";
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

sub handleGetLink {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response, {requireTopic => 0});
  return unless $params;

  my $id = $params->{id};
  my $type = $params->{type} || '';
  my $fileName = $params->{filename} || '';
  my $expand = Foswiki::Func::isTrue($params->{expand}, 0);
  my $web = $params->{web};
  my $topic = $params->{topic};
  my $text = $params->{text};

  my ($meta) = Foswiki::Func::readTopic($web, $topic);
  my $tml = $this->getAttachmentLink($meta, $fileName, $type, $text);
  $tml = Foswiki::Func::decodeFormatTokens($tml);

  my $html;

  if ($expand) {
    $html = $tml;
    $html = Foswiki::Func::expandCommonVariables($html, $topic, $web, $meta) if $html =~ /%/;
    $html = Foswiki::Func::renderText($html, $web, $topic);
  } 

  # better late than never
  $text = $fileName unless defined $text && $text ne "";
  $tml =~ s/\$text\b/$text/;
  $html =~ s/\$text\b/$text/ if $html;

  $this->printJSONRPC($response, 0, {
    html => $html,
    tml => $tml
  }, $id)
}

sub getAttachmentLink {
  my ($this, $meta, $fileName, $type, $text) = @_;

  my $attachment = $meta->get('FILEATTACHMENT', $fileName);
  my $fileComment = $attachment->{comment} // '';
  my $fileTime = Foswiki::Func::formatTime($attachment->{date} || 0);
  my $filePath = $Foswiki::cfg{PubDir} . '/' . $meta->web . '/' . $meta->topic . '/' . $fileName;
  my ($fileExt) = $fileName =~ m/(?:.*\.)*([^.]*)/;
  $fileExt //= '';
  my $web = $meta->web;
  my $topic = $meta->topic;

  if ($topic eq 'none') {
    $web = '%WEB%';
    $topic = '%TOPIC%';
  }

  my $fileUrl = Foswiki::Func::getPubUrlPath($web, $topic, $fileName);


  my $width = "";
  my $height = "";
  my $geom = "";
  my $format;

  if (defined $text && $text ne "") {
    $format = $this->getAttachmentFileFormat($web, $topic);
  } else {
    $format = $this->getAttachmentFormat($fileName, $type);
  }
  return "" if $format eq "";

  # only support values if ImagePlugin is installed
  if ($format =~ /\$width|\$height|\$size/) {
    ($width, $height) = $this->ping($filePath);
    $geom = "width='$width' height='$height'";
  }


  $format =~ s/\$name\b/$fileName/;    # deprecated
  $format =~ s/\$filename\b/$fileName/g;
  $format =~ s/\$web\b/$web/g;
  $format =~ s/\$topic\b/$topic/g;
  $format =~ s/\$fileurl\b/$fileUrl/g;
  $format =~ s/\$fileext\b/$fileExt/;

  # SMELL: backwards compatibility ... 
  $format =~ s/\\t/\t/g;
  $format =~ s/\\n/\n/g;

  $format =~ s/\$comment\b/$fileComment/g;
  $format =~ s/\$size\b/$geom/g;
  $format =~ s/\$width\b/$width/g;
  $format =~ s/\$height\b/$height/g;
  $format =~ s/\$date\b/$fileTime/g;

  $format =~ s/^\s+//;
  $format =~ s/\s+$//;

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
  $type =~ s/^_+/_/;

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

  push @prefNames, 'ATTACHED_FILE_FORMAT';
  push @prefNames, 'ATTACHEDFILELINKFORMAT'; # backwards compatibility

  foreach my $prefName (@prefNames) {
    $format = Foswiki::Func::getPreferencesValue($prefName);
    last if $format;
  }

  $format = '$n   * [[$percntATTACHURLPATH{"$filename"}$percnt][$filename]]' unless defined $format;

  return $format;
}

sub getAttachmentFileFormat {
  my ($this, $web, $topic) = @_;

  my $format;
  my @prefNames = ();

  push @prefNames, 'ATTACHED_FILE_FORMAT';
  push @prefNames, 'ATTACHEDFILELINKFORMAT'; # backwards compatibility

  foreach my $prefName (@prefNames) {
    $format = Foswiki::Func::getPreferencesValue($prefName);
    last if $format;
  }

  $format = '[[$percntPUBURLPATH$percnt/$web/$topic/$filename][$text]]' unless $format;

  #if ($web eq $this->{session}{webName} && $topic eq $this->{session}{topicName}) {
  #  $format =~ s/\$percntPUBURLPATH\$percnt\/\$web\/\$topic/\$percntATTACHURLPATH\$percnt/g;
  #  $format =~ s/\$percntPUBURL\$percnt\/\$web\/\$topic/\$percntATTACHURL\$percnt/g;
  #}

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

