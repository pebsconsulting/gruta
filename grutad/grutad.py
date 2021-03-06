#!/usr/bin/env python

import socket, threading
import json

class Grutad:
    def __init__(self, host, port, file):
        self.file = file

        self.save_db_period = 60

        try:
            with open(file, "r") as f:
                self.log("Started loading db")
                self.db = json.loads(f.read())
                self.log("Finished loading db")

        except:
            self.db = {}

        self.db_changed = False

        self.db_lock = threading.Lock()

        threading.Timer(self.save_db_period, self.save_db).start()

        self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        self.s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.s.bind((host, port))
        self.s.listen(4)

    def log(self, str):
        print str

    def accept(self):
        return self.s.accept()

    def save_db(self):

        if self.db_changed:
            self.log("Started syncing db")

            self.db_lock.acquire()

            with open(self.file, "w") as f:
                f.write(json.dumps(self.db))

            self.db_lock.release()

            self.log("Finished syncing db")

        threading.Timer(self.save_db_period, self.save_db).start()

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
        elif cmd == "del":
            ret = self.delete()
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

        if not q.get('_id'):
            # query
            try:
                s = self.grutad.db[q['_set']]
                l = s.keys()

                _s = q.get('_sort')
                _o = q.get('_offset')
                _n = q.get('_num')

                if _s is not None:
                    l = sorted(l, reverse=(int(_s) < 0))

                if _o is not None:
                    _o = int(_o)
                else:
                    _o = 0

                if _n is not None:
                    _n = int(_n) + _o
                else:
                    _n = len(l)

                l = l[_o:_n]

                self.sock.send("LIST\n");

                for i in l:
                    self.write_obj(s[i])

                self.sock.send(".\n")

            except KeyError:
                self.sock.send("ERROR\n")

        else:
            # single object
            try:
                o = self.grutad.db[q['_set']][q['_id']]

                self.write_obj(o)

            except KeyError:
                self.sock.send("ERROR\n")

            pass

        return True

    def put(self):
        o = self.read_obj()

        self.grutad.db_lock.acquire()

        try:
            _set = o['_set']

            s = self.grutad.db.get(_set)

            if not s:
                s = {}

            del(o['_set'])
            s[o['_id']] = o

            self.grutad.db[_set] = s
            self.grutad.db_changed = True

            self.sock.send("OK\n")

        except KeyError:
            self.sock.send("ERROR\n")

        self.grutad.db_lock.release()

        return True

    def delete(self):
        o = self.read_obj()

        self.grutad.db_lock.acquire()

        try:
            s = self.grutad.db[o['_set']]

            del(s[o['_id']])

            self.grutad.db[o['_set']] = s
            self.grutad.db_changed = True

            self.sock.send("OK\n")

        except KeyError:
            self.sock.send("ERROR\n")

        self.grutad.db_lock.release()

        return True


if __name__ == '__main__':
    g = Grutad('', 8045, 'qq.json')

    while True:
        Grutad_c(g.accept(), g).start()
