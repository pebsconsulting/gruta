CGIROOT=/var/www/cgi-bin

install_cgi: gruta
	install -o root -g root -m 755 gruta.cgi $(CGIROOT)/gruta.cgi
