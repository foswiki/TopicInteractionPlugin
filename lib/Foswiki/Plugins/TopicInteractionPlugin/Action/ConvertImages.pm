# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2026 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::TopicInteractionPlugin::Action::ConvertImages;

use strict;
use warnings;

use Error qw( :try );
use Image::Magick ();
use File::Temp ();
use Foswiki::Func ();
use Foswiki::Plugins::TopicInteractionPlugin::Action ();
our @ISA = ('Foswiki::Plugins::TopicInteractionPlugin::Action');

sub handle {
  my ($this, $response) = @_;

  my $params = $this->prepareAction($response);
  return unless $params;

  my $web = $params->{web};
  my $topic = $params->{topic};
  my $id = $params->{id};

  # check permissions
  my ($meta) = Foswiki::Func::readTopic($web, $topic);

  unless ($meta->haveAccess("CHANGE")) {
    $this->printJSONRPC($response, 102, "Access denied", $id);
    return;
  }

  my ($oopsUrl, $loginName, $unlockTime) = Foswiki::Func::checkTopicEditLock($web, $topic);
  my $lockWikiName = Foswiki::Func::getWikiName($loginName);
  my $wikiName = Foswiki::Func::getWikiName();
  if ($unlockTime && $wikiName ne $lockWikiName) {
    $this->printJSONRPC($response, 105, "Topic is locked by $loginName", $id);
    return; 
  }

  my $format = $params->{format} // 'webp';
  #print STDERR "format=$format\n";
  unless ($format =~ /^(webp|jpe?g|png|avif)$/i) {
    $this->printJSONRPC($response, 106, "Can't convert to format $format", $id);
    return;
  }

  my $quality = $params->{quality} // 75;
  #print STDERR "quality=$quality\n";

  my $original = $params->{original} // 'keep';
  #print STDERR "original=$original\n";

  my $overwrite = Foswiki::Func::isTrue($params->{overwrite}, 0);
  #print STDERR "overwrite=$overwrite\n";

  my %fileNames = 
      map {$_ => 1} 
      grep {/\.(gif|png|webp|avif|jpe?g|heic|heif|jxl|tiff?|bmp|xcf|ico|pdf|ps|psd|pptx?|docx?|odt|xlsx?|mp4|mpe?g|mpe|m4v|ogv|qt|mov|flv|asf|asx|mkv|avi|wmv|wm|wmx|wvx|movie|swf|webm)$/i} 
      $this->getFileNames($meta);

  my @fileNames = keys %fileNames;
  throw Error::Simple("no files specified") unless @fileNames;

  #print STDERR "fileNames=".join(", ", @fileNames)."\n";

  my $pubDir = $Foswiki::cfg{PubDir};
  $web =~ s/\./\//g;

  my $totalConverted = 0;
  my $totalSkipped = 0;

  # check all files first
  foreach my $fileName (@fileNames) {
    throw Error::Simple("attachment $fileName does not exist")
      unless Foswiki::Func::attachmentExists($web, $topic, $fileName);

    my $sourcePath = "$pubDir/$web/$topic/$fileName";
    throw Erorr::Simple("file not found: $fileName")
      unless -e $sourcePath;
  }

  # now convert
  my $mustSave = 0;
  foreach my $fileName (@fileNames) {
    my $sourcePath = "$pubDir/$web/$topic/$fileName";
    my $targetFile = $fileName;
    $targetFile =~ s/\.(.*?)$/.$format/g;

    my $targetPath = "$pubDir/$web/$topic/$targetFile";
    if (!$overwrite && -e $targetPath) {
      $totalSkipped++;
      next;
    }

    my $tempFile = new File::Temp(SUFFIX => ".$format");

    #print STDERR "converting $sourcePath to $tempFile\n";

    my $frame = "";
    $frame = "[0]" if _isFramish($fileName);
    
    my $image = Image::Magick->new();
    my $error = $image->Read($sourcePath.$frame);

    throw Error::Simple("error reading $fileName: $error")
      if $error;

    $error = $image->AutoOrient();
    throw Error::Simple("error auto-rotating $fileName: $error")
      if $error;

    $error = $image->Write(filename => $tempFile, quality => $quality);
    throw Error::Simple("error writing $fileName: $error")
      if $error;

    undef $image;

    # first deal with source
    if ($original eq 'delete') {
      $this->trashAttachment($meta, $fileName);
    } 

    # then attach target
    $meta->attach(
      name => $targetFile,
      file => $tempFile,
      filesize => _fileSize($tempFile),
      minor => 1,
      dontlog => 1,
      comment => 'Auto-attached by TopicInteractionPlugin',
    );

    if ($original eq 'hide') {
      my $attachment = $meta->get("FILEATTACHMENT", $fileName);
      if ($attachment) {
        $attachment->{attr} = "h";
        $mustSave = 1;
      }
    } 

    $totalConverted++;
  }

  my $error;
  try {
    $meta->save() if $mustSave;
  } catch Error::Simple with {
    $error = shift->{-text};
    $this->writeDebug("ERROR: $error");
  };

  if ($error) {
    $this->printJSONRPC($response, 1, $error, $id);
  } else {
    my $reply = "converted $totalConverted";
    $reply .= ", skipped $totalSkipped" if $totalSkipped;
    $reply .= " image(s)";
 
    $this->printJSONRPC($response, 0, $reply, $id)
  }
}

sub _fileSize {
  my $filePath = shift;
  my @stat = stat($filePath);
  return $stat[7] // 0;
}

sub _isFramish {
  my $file = shift;

  return 1 if _isVideo($file) || $file =~ /\.(pdf|ps|psd|pptx?|docx?|odt|xlsx?)$/i;
  return 0;
}

sub _isVideo {
  my $file = shift;

  return 1 if $file =~ /\.(mp4|mpe?g|mpe|m4v|ogv|qt|mov|flv|asf|asx|mkv|avi|wmv|wm|wmx|wvx|movie|swf|webm)$/;
  return 0;
}


1;
