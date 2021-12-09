basedir := $(shell pwd)
envfile := $(basedir)/.env
include $(envfile)

PATH := $(PATH):$(PREFIX)/bin
cc := $(TARGET)-gcc
as := $(TARGET)-as
ld := $(TARGET)-ld

all: boot kernel link
boot:
kernel:
link:
clean:
	rm -rf $(BUILDDIR)