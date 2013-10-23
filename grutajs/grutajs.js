/*
                 __         _         _   
  ___ _______ __/ /____ _  (_)__     (_)__
 / _ `/ __/ // / __/ _ `/ / (_-<_   / (_-<
 \_, /_/  \_,_/\__/\_,_/_/ /___(_)_/ /___/
/___/                 |___/     |___/     

(C) 2013 Angel Ortega <angel@triptico.com>

*/

function Gruta(config) {
    if (config != undefined) {
        /* combine configuration */
        for (var e in config)
            this.config[e] = config[e];
    }
}

Gruta.prototype = {

config: {
    /* default configuration */
    site_name:      'Gruta',
    cards_def:      8,
    cards_more:     4,
    menu_tagsets:   [],
    tagset_name:    {},
    tagset_image:   {},
    menu_colors:    [
        '#000000',
        '#00c3c3',      /* cyan:    0,195,195 */
        '#b81800',      /* red:     184,24,0 */
        '#9600b4',      /* purple:  150,0,180 */
        '#00a53c',      /* green:   0,165,60 */
        '#fa5f00',      /* orange:  250,95,0 */
        '#ffc000',      /* yellow:  255,192,0 */
        '#009bff',      /* blue:    0,155,255 */
        '#bbbbbb'      /* grey */
    ]
},

state: {
    /* state */
    tagset_name:    '',
    tagset_color:   '#000',
    topic_id:       '',
    id:             ''
},

cache: {
    /* cache */
    story:  {},
    tagset: {}
},

http_req_obj: function() {
    /* creates an HTTP request object */
    var req = false;

    if (window.XMLHttpRequest) {
        try { req = new XMLHttpRequest(); }
        catch (e) { req = false; }
    }
    else
    if (window.ActiveXObject) {
        try { req = new ActiveXObject("Msxml2.XMLHTTP"); }
        catch (e) {
            try { req = new ActiveXObject("Microsoft.XMLHTTP"); }
            catch (e) { req = false; }
        }
    }

    return req;
},

api_query: function(args) {
    /* executes an HTTP query to Gruta's API */
    var req = this.http_req_obj();
    var url = "/g.cgi?t=API;" + args;

    req.open('GET', url, false);
    req.send(null);

    if (req.status == 200) {
        var j = req.responseText;
        s = JSON.parse(j);
    }

    return s;
},

api_story_load: function(topic_id, id) {
    /* loads a story from the database */
    return this.api_query("c=story;topic_id=" + topic_id + ";id=" + id);
},

api_tagset_load: function (tagset_name, offset, num) {
    /* loads a set from the database */
    if (offset == undefined)
        offset = 0;

    var url = "c=stories_by_date;num=" + num + ";offset=" + offset;

    if (tagset_name != 'INDEX') {
        url += ";tags=" + tagset_name;
    }

    return this.api_query(url);
},

db_story_get: function(topic_id, id) {
    /* gets a story from the cache or loads it */
    var key = id + "@" + topic_id;
    var s;

    /* try in the cache */
    if ((s = this.cache.story[key]) == undefined) {
        /* not there; ask the database */
        s = this.api_story_load(topic_id, id);
        /* now there is */
        this.cache.story[key] = s;
    }

    return s;
},

db_tagset_get: function(tagset_name, offset, num) {
    /* gets a tagset from the tagset cache or loads it */
    var tagset;

    /* default values */
    if (offset == undefined) offset = 0;

    if ((tagset = this.cache.tagset[tagset_name]) == undefined) {
        /* no specific count? pick default */
        if (num == undefined)
            num = this.config.cards_def;

        /* not cached; pick the full possible set */
        tagset = this.api_tagset_load(tagset_name, 0, offset + num);

        /* and cache it */
        this.cache.tagset[tagset_name] = tagset;
    }
    else {
        /* no specific count? take all */
        if (num == undefined)
            num = tagset.length;

        /* already cached; are all elements available? */
        if (tagset.length < offset + num) {
            /* no; ask for the rest */
            tagset = tagset.concat(this.api_tagset_load(tagset_name,
                tagset.length, num + (offset - tagset.length)));

            /* and cache it */
            this.cache.tagset[tagset_name] = tagset;
        }
    }

    /* return only the wanted part */
    return tagset.slice(offset, offset + num);
},

ui_story_show: function() {
    /* gets a story, puts it in the story panel and shows it */
    document.getElementById('story').style.display =
    document.getElementById('veil').style.display = 'block';

    var e = document.getElementById('story_content');
    e.style.cursor = 'wait';
    e.innerHTML = "<h1>&#8987;</h1>"; /* show hourglass while loading */

    var s = this.db_story_get(this.state.topic_id, this.state.id);

    e.innerHTML     = s['body'];
    document.title  = s['title'];
    e.style.cursor  = 'default';
    e.scrollTop     = 0;
},

ui_story_hide: function() {
    /* hides the story panel */
    document.getElementById('story').style.display =
    document.getElementById('veil').style.display = 'none';
},

ui_deck_append: function(tagset, reset) {
    /* appends a tagset of stories to the deck */
    var n;
    var deck = document.getElementById("card_deck");

    if (reset)
        deck.innerHTML = '';

    for (n = 0; n < tagset.length; n++) {
        var e = tagset[n];
        var c = document.createElement("div");

        c.className = "card";

        var h = "<a href = '/#!" + e.id + "@" + e.topic_id + "'>";

        /* pick story's image or the default for this set */
        var img = e.image || this.config.tagset_image[this.state.tagset_name];

        if (img) {
            h += "<img src = '" + img + "'/>";
        }
        else {
            h += "<div class = 'full' style = 'background: " +
                this.state.tagset_color + "'> </div>";
        }

        h += "<h1>" + e.title + "</h1></a>";

        c.innerHTML = h;

        deck.appendChild(c);
    }
},

ui_load_more: function() {
    /* adds more story cards to the deck */
    var deck = document.getElementById("card_deck");
    var offset = deck.childElementCount;

    this.ui_deck_append(
        this.db_tagset_get(this.state.tagset_name,
            offset, this.config.cards_more)
    );

    /* move to bottom */
    window.scrollTo(0, document.body.scrollHeight);
},

ui_menu_update: function() {
    var e, n = 1, m = 0;

    while (e = document.getElementById("menu_opt_" + n)) {
        if (e.title == this.state.tagset_name) {
            m = n;
            e.style.background = this.config.menu_colors[n];
        }
        else
            e.style.background = "#000";

        n++;
    }

    /* store the selected color */
    this.state.tagset_color = this.config.menu_colors[m];
},

ui_menu_create: function() {
    /* fills the menu with the default tagsets */
    var n;
    var menu_bar = document.getElementById("menu_bar");

    menu_bar.innerHTML = '';

    for (n = 0; n < this.config.menu_tagsets.length; n++) {
        var s = this.config.menu_tagsets[n];

        var c = document.createElement("div");

        c.id                    = "menu_opt_" + n;
        c.title                 = s;
        c.className             = "menu_opt";
        c.style.borderTopColor  = this.config.menu_colors[n];

        var name = this.config.tagset_name[s] || s;

        var h = "<a href = '/#!" + encodeURI(s) + "'>";
        h += "<div class = 'full'> </div>" + name + "</a>";

        c.innerHTML = h;

        menu_bar.appendChild(c);
    }
},

ui_set_document_title: function() {
    /* sets the document title according to the state */
    /* FIXME: use also from ui_story_show() */

    var tsn = this.state.tagset_name;

    var t = this.config.site_name;

    if (this.config.tagset_name != '')
        t += ': ' + (this.config.tagset_name[tsn] || tsn);

    document.title = t;
},

ui_deck_show: function() {
    /* replace the deck with the current tagset */
    var tagset = this.db_tagset_get(this.state.tagset_name);

    if (tagset != undefined) {
        /* update the menu color, in case the tagset
           name is one of the menus */
        this.ui_menu_update();

        /* hide the story */
        this.ui_story_hide();

        /* add cards */
        this.ui_deck_append(tagset, 1);

        /* change title */
        this.ui_set_document_title();
    }
},

ui_on_hash_change: function() {
    /* handler for changes in the hash component of the url */
    var h = window.location.hash;

    if (h == "") {
        this.state.tagset_name = h;

        this.ui_deck_show();
    }
    else
    if (h.substr(0, 2) == "#!") {
        /* strip #! */
        h = h.substr(2);

        var at = h.indexOf("@");

        if (at == -1) {
            /* tagset */
            if (h == '')
                h = 'INDEX';

            this.state.tagset_name = decodeURI(h);

            this.ui_deck_show();
        }
        else {
            /* story */
            this.state.id       = h.substr(0, at);
            this.state.topic_id = h.substr(at + 1);

            this.ui_story_show();
        }
    }
},

ui_update: function() {
    var p = document.location.pathname;

    if (p != "/") {
        var pl = p.split("/");

        if (pl.length == 3) {
            if (pl[2].substr(-5) == ".html")
                pl[2] = pl[2].split(".")[0];

            if (pl[1] == "tag") {
                this.state.tagset_name = decodeURI(pl[2]);
                this.ui_deck_show();
            }
            else {
                this.state.topic_id = pl[1];
                this.state.id       = pl[2];
                this.ui_story_show();
            }
        }
    }
    else
        this.ui_on_hash_change();
},

start: function() {
    var self = this;

    self.ui_menu_create();
    self.ui_update();

    window.onhashchange = function() { self.ui_on_hash_change(); };
},

version: "0.0.0"

};
