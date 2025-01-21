FOSWIKI_ROOT?=~/foswiki/trunk/core
TARGET= \
  build/metadata.js \
  build/metadata.css \
  build/uploader.js \
  build/uploader.css \
  build/webdav.js

UPLOADER_SOURCE= \
  src/jquery.fileupload.uncompressed.js \
  src/foswiki.fileupload.uncompressed.js \
  src/legacy.fileupload.uncompressed.js 

METADATA_SOURCE= \
  src/detectos.uncompressed.js \
  src/webdav.uncompressed.js \
  src/foswiki.attachments.uncompressed.js

-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

.PRECIOUS: %.uncompressed.js

build/uploader.js: $(UPLOADER_SOURCE)
	@echo creating $@; $(JSMIN) $^ > $@

build/metadata.js: $(METADATA_SOURCE)
	@echo creating $@; $(JSMIN) $^ > $@

clean:
	rm -f build/* igp_* genpdf_* src/*.jslint 

.PHONY: git

git:
	git clone https://github.com/blueimp/jQuery-File-Upload.git git

ifneq (,$(wildcard git))
src/%.uncompressed.js: git/js/%.js
	@echo "generating $@"
	@$(CAT) $< > $@
endif
