all: sixaxis_bins

CC ?= gcc

sixaxis_bins:
	mkdir -p bins
	$(CC) sixaxis-timeout.c -o bins/sixaxis-timeout

clean:
	rm -f *~ bins/*

install:
	install -m 644 sixaxis@.service $(DESTDIR)/etc/systemd/system/
	install -m 755 sixaxis-helper.sh $(DESTDIR)/usr/bin/
	install -m 755 bins/sixaxis-timeout $(DESTDIR)/usr/sbin/
	install -m 644 99-sixaxis.rules $(DESTDIR)/etc/udev/rules.d

	@echo "Installation is Complete!"

uninstall:
	rm -f $(DESTDIR)/etc/systemd/system/sixaxis.service
	rm -f $(DESTDIR)/usr/bin/sixaxis-helper.sh
	rm -f $(DESTDIR)/usr/sbin/sixaxis-timeout
	rm -f $(DESTDIR)/etc/udev/rules.d/99-sixaxis.rules
