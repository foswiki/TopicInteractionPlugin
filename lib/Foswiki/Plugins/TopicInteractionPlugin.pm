# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2009-2024 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::TopicInteractionPlugin;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Request();
use Foswiki::Plugins::JQueryPlugin ();

our $VERSION = '10.00';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'Improved interaction with attachments and !DataForms';
our $LICENSECODE = '%$LICENSECODE%';
our $NO_PREFS_IN_TOPIC = 1;
our $core;
our $attachments;

BEGIN {
    # Backwards compatibility for Foswiki 1.1.x
    unless ( Foswiki::Request->can('multi_param') ) {
        no warnings 'redefine'; ## no critic
        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
        use warnings 'redefine';
    }
}

##############################################################################
sub initPlugin {

  Foswiki::Plugins::JQueryPlugin::registerPlugin("Uploader", 'Foswiki::Plugins::TopicInteractionPlugin::Uploader');
  Foswiki::Plugins::JQueryPlugin::registerPlugin("TipMetaData", 'Foswiki::Plugins::TopicInteractionPlugin::MetaData');

  Foswiki::Func::registerTagHandler('ATTACHMENTS', sub {
    return getAttachments(shift)->handle(@_);
  });

  # compatibility with AttachmentListPlugin
  Foswiki::Func::registerTagHandler('ATTACHMENTLIST', sub {
    return getAttachments(shift)->handle(@_);
  });

  Foswiki::Func::registerTagHandler('WEBDAVURL', sub {
    require Foswiki::Plugins::TopicInteractionPlugin::WebDAVUrl;
    return Foswiki::Plugins::TopicInteractionPlugin::WebDAVUrl::handle(@_);
  });

  Foswiki::Func::registerRESTHandler('changeproperties', sub { 
      return getCore(shift)->restChangeProperties(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('delete', sub {
      return getCore(shift)->restDelete(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('move', sub {
      return getCore(shift)->restMove(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('upload', sub {
      return getCore(shift)->restUpload(@_);
    },
    authenticate => 1,
    validate => 0,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('createlink', sub {
      return getCore(shift)->restCreateLink(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('createimagegallery', sub {
      return getCore(shift)->restCreateImageGallery(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('download', sub {
      return getCore(shift)->restDownload(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('hide', sub {
      return getCore(shift)->restHide(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  Foswiki::Func::registerRESTHandler('unhide', sub {
      return getCore(shift)->restUnhide(@_);
    },
    authenticate => 1,
    validate => 1,
    http_allow => 'POST',
  );

  # init 
  getCore();

  return 1;
}

##############################################################################
sub finishPlugin {
  undef $core;

  if ($attachments) {
    $attachments->finish;
    undef $attachments;
  }
}
##############################################################################
sub getCore {
  my $session = shift;

  unless ($core) {
    require Foswiki::Plugins::TopicInteractionPlugin::Core;
    $core = Foswiki::Plugins::TopicInteractionPlugin::Core->new($session);
  }

  return $core;
}

##############################################################################
sub getAttachments {
  my $session = shift;

  unless ($attachments) {
    require Foswiki::Plugins::TopicInteractionPlugin::Attachments;
    $attachments = Foswiki::Plugins::TopicInteractionPlugin::Attachments->new($session);
  }

  return $attachments;
}

##############################################################################
# keep a t=thumbnail attr in attachments
sub beforeUploadHandler {
  my ($attachment, $meta) = @_;

  my $oldAttachment = $meta->get("FILEATTACHMENT", $attachment->{name});

  if ($oldAttachment && $oldAttachment->{attr} && ($oldAttachment->{attr} || '') =~ /t/) {
    $attachment->{isthumbnail} = 1;
  }
}

##############################################################################
sub afterUploadHandler {
  my ($attachment, $meta) = @_;

  if ($attachment->{isthumbnail}) {
    delete $attachment->{isthumbnail};

    my $oldAttr = $attachment->{attr} || '';
    my %attrs = map {$_=>1} split(//, $oldAttr);
    $attrs{t} = 1;
    my $newAttr = join("", sort keys %attrs);
    if ($oldAttr ne $newAttr) {
      $attachment->{attr} = $newAttr;
      $meta->putKeyed("FILEATTACHMENT", $attachment);
      $meta->save();
    }
  }
}

1;
