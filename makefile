PREFIX=/usr/local/bin

install:
	install -o root -g root -m 755 gruta.cgi $(PREFIX)/gruta.cgi
