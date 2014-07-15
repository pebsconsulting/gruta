#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct gd_val {
    char *k;
    struct gd_val *v;
    struct gd_val *n;
};



#define POKE_STEP 16

char *line_poke(char *s, int c, size_t *z, off_t *n)
{
    if (*z == *n) {
        *z += POKE_STEP;
        s = realloc(s, *z);
    }

    s[(*n)++] = c;

    return s;
}


char *line_read(FILE *f)
{
    char *s = NULL;
    size_t z = 0;
    off_t n = 0;
    int c;

    while ((c = fgetc(f)) != EOF && c != '\r' && c != '\n')
        s = line_poke(s, c, &z, &n);

    if (c == '\r')
        c = fgetc(f);

    s = line_poke(s, '\0', &z, &n);

    if (c == EOF) {
        free(s);
        s = NULL;
    }

    return s;
}


struct gd_val *gd_val_free(struct gd_val *o)
{
    if (o) {
        free(o->k);
        gd_val_free(o->v);
        gd_val_free(o->n);

        free(o);
    }

    return NULL;
}


struct gd_val *gd_val_new(char *k, struct gd_val *v, struct gd_val *n)
{
    struct gd_val *o = (struct gd_val *)malloc(sizeof(*o));

    o->k = k;
    o->v = v;
    o->n = n;

    return o;
}


struct gd_val *gd_val_set(struct gd_val *o, char *k, struct gd_val *v)
{
    if (o) {
        int i = strcmp(k, o->k);

        if (i == 0) {
            free(o->k);
            gd_val_free(o->v);

            o->k = k;
            o->v = v;
        }
        else
        if (i < 0)
            o = gd_val_new(k, v, o);
        else
            o->n = gd_val_set(o->n, k, v);
    }
    else
        o = gd_val_new(k, v, NULL);

    return o;
}


struct gd_val *gd_val_get(struct gd_val *o, char *k)
{
    if (o) {
        int i = strcmp(k, o->k);

        if (i < 0)
            o = NULL;
        else
        if (i > 0)
            o = gd_val_get(o->n, k);
    }

    return o;
}


struct gd_val *gd_val_append(struct gd_val *o, char *k, struct gd_val *v)
{
    if (o)
        o->n = gd_val_append(o->n, k, v);
    else
        o = gd_val_new(k, v, NULL);

    return o;
}


struct gd_val *obj_read(FILE *i, FILE *o)
{
    struct gd_val *l = NULL;

    fprintf(o, "OK ready to receive object\n");

    for (;;) {
        char *p = line_read(i);
        char *k;

        if (p == NULL || strcmp(p, ".") == 0) {
            free(p);
            break;
        }

        if (p[0] == '>') {
            char *t = strdup(p + 1);
            free(p);
            p = t;
        }

        k = p;

        p = line_read(i);

        if (p == NULL || strcmp(p, ".") == 0) {
            free(k);
            free(p);
            break;
        }

        l = gd_val_set(l, k, gd_val_new(p, NULL, NULL));
    }

    return l;
}



struct gd_val *list_read(FILE *i, FILE *o, int *n)
{
    struct gd_val *l = NULL;
    *n = 0;

    fprintf(o, "OK ready to receive list\n");

    for (;;) {
        char *p = line_read(i);

        if (p == NULL || strcmp(p, ".") == 0) {
            free(p);
            break;
        }

        if (p[0] == '>') {
            char *t = strdup(p + 1);
            free(p);
            p = t;
        }

        l = gd_val_append(l, p, NULL);
        (*n)++;
    }

    return l;
}



void list_write(struct gd_val *l, FILE *i, FILE *o)
{
    fprintf(o, "OK list follows\n");

    while (l) {
        char *s = l->k;

        if (strcmp(s, ".") == 0 || s[0] == '>')
            fprintf(o, ">%s\n", s);
        else
            fprintf(o, "%s\n", s);

        l = l->n;
    }

    fprintf(o, ".\n");
}


void obj_write(struct gd_val *l, FILE *o, FILE *p)
{
    if (p)
        fprintf(p, "OK object follows\n");

    while (l) {
        char *s = l->k;

        if (strcmp(s, ".") == 0 || s[0] == '>')
            fprintf(o, ">%s\n", s);
        else
            fprintf(o, "%s\n", s);

        fprintf(o, "%s\n", l->v->k);

        l = l->n;
    }

    fprintf(o, ".\n");
}


struct gd_val *cmd_set_store(struct gd_val *set, char *pk, FILE *i, FILE *o)
{
    struct gd_val *obj;
    struct gd_val *key;

    obj = obj_read(i, o);

    if ((key = gd_val_get(obj, pk)) != NULL) {
        set = gd_val_set(set, strdup(key->v->k), obj);
        fprintf(o, "OK stored\n");
    }
    else {
        fprintf(o, "ERROR '%s' pk not found\n", pk);
        gd_val_free(obj);
    }

    return set;
}


struct gd_val *cmd_set_store_2(struct gd_val *set, char *pk1, char *pk2, FILE *i, FILE *o)
{
    struct gd_val *obj;
    struct gd_val *key1;
    struct gd_val *key2;

    obj = obj_read(i, o);

    if ((key1 = gd_val_get(obj, pk1)) != NULL && (key2 = gd_val_get(obj, pk2)) != NULL) {
        char *npk = malloc(strlen(key1->v->k) + strlen(key2->v->k) + 2);

        strcpy(npk, key1->v->k);
        strcat(npk, "/");
        strcat(npk, key2->v->k);

        set = gd_val_set(set, npk, obj);
        fprintf(o, "OK %s stored\n", npk);
    }
    else {
        fprintf(o, "ERROR '%s/%s' pk not found\n", pk1, pk2);
        gd_val_free(obj);
    }

    return set;
}


void cmd_set_get(struct gd_val *set, char *setname, FILE *i, FILE *o)
{
    struct gd_val *a;
    int n;

    a = list_read(i, o, &n);

    if (n) {
        struct gd_val *obj;

        if ((obj = gd_val_get(set, a->k)) != NULL) {
            obj_write(obj->v, o, o);
        }
        else
            fprintf(o, "ERROR %s %s not found\n", a->k, setname);
    }
    else
        fprintf(o, "ERROR too few arguments\n");

    gd_val_free(a);
}


struct gd_val *about        = NULL;
struct gd_val *topics       = NULL;
struct gd_val *users        = NULL;
struct gd_val *sessions     = NULL;
struct gd_val *templates    = NULL;
struct gd_val *stories      = NULL;


void set_dump(struct gd_val *set, char *cmd, FILE *o)
{
    while (set) {
        fprintf(o, "%s\n", cmd);
        obj_write(set->v, o, NULL);
        set = set->n;
    }
}


void dump(FILE *o)
{
    set_dump(topics,    "store_topic",      o);
    set_dump(users,     "store_user",       o);
    set_dump(templates, "store_template",   o);

    fprintf(o, "bye\n");
}


void dialog(FILE *i, FILE *o)
{
    int done = 0;

    while (!done) {
        char *cmd = line_read(i);

        if (cmd == NULL || strcmp(cmd, "bye") == 0) {
            done = 1;
        }
        else
        if (strcmp(cmd, "about") == 0) {
            obj_write(about, o, o);
        }
        else
        if (strcmp(cmd, "topic") == 0) {
            cmd_set_get(topics, "topic", i, o);
        }
        else
        if (strcmp(cmd, "store_topic") == 0) {
            topics = cmd_set_store(topics, "id", i, o);
        }
        else
        if (strcmp(cmd, "topics") == 0) {
            list_write(topics, i, o);
        }
        else
        if (strcmp(cmd, "user") == 0) {
            cmd_set_get(users, "user", i, o);
        }
        else
        if (strcmp(cmd, "store_user") == 0) {
            users = cmd_set_store(users, "id", i, o);
        }
        else
        if (strcmp(cmd, "users") == 0) {
            list_write(users, i, o);
        }
        else
        if (strcmp(cmd, "template") == 0) {
            cmd_set_get(templates, "template", i, o);
        }
        else
        if (strcmp(cmd, "store_template") == 0) {
            templates = cmd_set_store(templates, "id", i, o);
        }
        else
        if (strcmp(cmd, "templates") == 0) {
            list_write(templates, i, o);
        }
        else
        if (strcmp(cmd, "store_story") == 0) {
            stories = cmd_set_store_2(stories, "topic_id", "id", i, o);
        }
        else
        if (strcmp(cmd, "_dump") == 0) {
            FILE *f;

            f = fopen("dump.bin", "w");
            dump(f);
            fclose(f);
        }
        else {
            fprintf(o, "ERROR %s command not found\n", cmd);
        }

        free(cmd);
    }
}


int main(int argc, char *argv[])
{
    FILE *f;

    about = gd_val_set(about, strdup("proto_version"),  gd_val_new(strdup("0.9"), NULL, NULL));
    about = gd_val_set(about, strdup("server_version"), gd_val_new(strdup("0.0"), NULL, NULL));
    about = gd_val_set(about, strdup("server_id"),      gd_val_new(strdup("grutad.c"), NULL, NULL));

    if ((f = fopen("dump.bin", "r")) != NULL) {
        dialog(f, stdout);
        fclose(f);
    }

    dialog(stdin, stdout);

    return 0;
}