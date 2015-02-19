#!/usr/bin/env python

import socket, threading

class Grutad:
    def __init__(self, host, port):
        self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        self.s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.s.bind((host, port))
        self.s.listen(4)

        self.db = {}
        self.db_lock = threading.Lock()

    def accept(self):
        return self.s.accept()

class Grutad_c(threading.Thread):
    def __init__(self, (socket,address), grutad):
        threading.Thread.__init__(self)
        self.sock   = socket
        self.addr   = address
        self.chan   = self.sock.makefile()
        self.grutad = grutad

    def readline(self):
        return self.chan.readline().rstrip()

    def run(self):
        while True:
            cmd = self.readline()

            if not self.process(cmd):
                break

        self.sock.close()

    def process(self, cmd):
        ret = True

        if cmd == "bye":
            ret = False
        elif cmd == "about":
            ret = self.about()
        elif cmd == "get":
            ret = self.get()
        elif cmd == "put":
            ret = self.put()
        else:
            self.sock.send("ERROR\n")

        return ret

    def read_obj(self):
        o = {}
        self.sock.send("READY\n")

        while True:
            k = self.readline()

            if k == '.':
                break

            v = self.readline()
            o[k] = v

        return o

    def write_obj(self, o):
        self.sock.send("OBJ\n")

        for k, v in o.iteritems():
            self.sock.send(k + "\n")
            self.sock.send(v + "\n")

        self.sock.send(".\n")

    def about(self):
        o = {
            'proto_version':    '0.20',
            'server_version':   '0.0',
            'server_id':        'grutad.py'
        }

        self.write_obj(o)
        return True

    def get(self):
        q = self.read_obj()

        if q.get('_from') or q.get('_num') or q.get('_offset') or q.get('_sort'):
            # query
            pass

        else:
            # single object
            try:
                o = self.grutad.db[q['_set']][q['_id']]

                self.write_obj(o)

            except:
                self.sock.send("ERROR\n")

            pass

        return True

    def put(self):
        o = self.read_obj()

        try:
            self.grutad.db_lock.acquire()

            s = self.grutad.db.get(o['_set'])

            if not s:
                s = {}

            s[o['_id']] = o

            self.grutad.db[o['_set']] = s

            self.grutad.db_lock.release()

            self.sock.send("OK\n")

            print repr(self.grutad.db)

        except:
            self.sock.send("ERROR\n")

        return True

g = Grutad('', 8045)

while True:
    Grutad_c(g.accept(), g).start()
