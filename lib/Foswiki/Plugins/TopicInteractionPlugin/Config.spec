# ---+ Extensions
# ---++ TopicInteractionPlugin

# **STRING**
# This is the preference list of engines to test.
# Available engines: html5, flash, silverlight, gears, browserplus, html4
# Note that silverlight, gears and browserplus are disabled by default as these browser extensions are mostly unsupported.
$Foswiki::cfg{TopicInteractionPlugin}{UploadEngines} = 'html5, html4';

# **REGEX EXPERT**
# Specify a regular expression matching fileextensions to be webdav enabled in the attachments list of a topic. 
# By default this is undefined. Use 
# <code>qr/((xlt|xls|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp/</code>
# as a good coverage of the most common office document extensions.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVFilter} = '((xlt|xls|csv|ppt|pps|pot|doc|dot)(x|m)?)|odc|odb|odf|odg|otg|odi|odp|otp|ods|ots|odt|odm|ott|oth|mpp|rtf|txt|vsd';

# **SELECT ,libreoffice, msoffice CHECK="undefok emptyok"**
# Set the default office suite that will be used to open webdav-enabled links. This setting can be customized
# further by setting the preference <code>WEBDAV_OFFICE_SUITE</code> in the SitePreferences or the user preferences.
$Foswiki::cfg{TopicInteractionPlugin}{DefaultOfficeSuite} = '';

# **STRING**
# Defines the uri pattern for webdav links. Empty this in case you don't use webdav enabled urls.
$Foswiki::cfg{TopicInteractionPlugin}{WebDAVUrl} = 'webdav://$host/dav/$web/$topic_files/$attachment';

# ---++ JQueryPlugin
# ---+++ Extra plugins

# **STRING**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Uploader}{Module} = 'Foswiki::Plugins::TopicInteractionPlugin::Uploader';

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Uploader}{Enabled} = 1;

1;
