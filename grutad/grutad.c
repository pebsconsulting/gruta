#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <pthread.h>
#include <semaphore.h>

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


struct gd_val *gd_val_delete(struct gd_val *o, char *k)
{
    if (o) {
        int i = strcmp(k, o->k);

        if (i == 0) {
            struct gd_val *d = o;
            o = o->n;
            d->n = NULL;
            gd_val_free(d);
        }
        else
        if (i > 0)
            o->n = gd_val_delete(o->n, k);
    }

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


struct gd_val *about        = NULL;
struct gd_val *topics       = NULL;
struct gd_val *users        = NULL;
struct gd_val *sessions     = NULL;
struct gd_val *templates    = NULL;
struct gd_val *stories      = NULL;

struct gd_set {
    sem_t           sem;
    pthread_mutex_t mutex;
    struct gd_val   *set;
};

int gd_max_threads = 256;

enum {
    SET_ABOUT,
    SET_TOPICS,
    SET_USERS,
    SET_SESSIONS,
    SET_TEMPLATES,
    SET_STORIES,
    SET_COMMENTS,
    SET_NUM
};

struct gd_set gd_sets[SET_NUM];


/** sets **/

void gd_set_init(struct gd_set *s)
{
    sem_init(&s->sem, 0, gd_max_threads);
    pthread_mutex_init(&s->mutex, NULL);
    s->set = NULL;
}


enum {
    UNLOCK_RO,
    UNLOCK_RW,
    LOCK_RO,
    LOCK_RW
};

void gd_set_lock(struct gd_set *s, int type)
{
    int n;

    switch (type) {
    case LOCK_RO:
        sem_wait(&s->sem);
        break;

    case UNLOCK_RO:
        sem_post(&s->sem);
        break;

    case LOCK_RW:
        pthread_mutex_lock(&s->mutex);

        for (n = 0; n < gd_max_threads; n++)
            sem_wait(&s->sem);

        pthread_mutex_unlock(&s->mutex);
        break;

    case UNLOCK_RW:
        for (n = 0; n < gd_max_threads; n++)
            sem_post(&s->sem);
        break;
    }
}


void gd_set_dump(struct gd_set *s, char *cmd, FILE *o)
{
    struct gd_val *v;

    gd_set_lock(s, LOCK_RO);

    v = s->set;
    while (v) {
        fprintf(o, "%s\n", cmd);
        obj_write(v->v, o, NULL);
        v = v->n;
    }

    gd_set_lock(s, UNLOCK_RO);
}


void gd_set_list_write(struct gd_set *s, FILE *i, FILE *o)
{
    gd_set_lock(s, LOCK_RO);

    list_write(s->set, i, o);

    gd_set_lock(s, UNLOCK_RO);
}


void gd_set_get(struct gd_set *s, char *setname, FILE *i, FILE *o)
{
    struct gd_val *a;
    int n;

    a = list_read(i, o, &n);

    gd_set_lock(s, LOCK_RO);

    if (n) {
        struct gd_val *obj;

        if ((obj = gd_val_get(s->set, a->k)) != NULL) {
            obj_write(obj->v, o, o);
        }
        else
            fprintf(o, "ERROR %s %s not found\n", a->k, setname);
    }
    else
        fprintf(o, "ERROR too few arguments\n");

    gd_set_lock(s, UNLOCK_RO);

    gd_val_free(a);
}


void dump(FILE *o)
{
    gd_set_dump(&gd_sets[SET_TOPICS],    "store_topic",      o);
    gd_set_dump(&gd_sets[SET_USERS],     "store_user",       o);
    gd_set_dump(&gd_sets[SET_TEMPLATES], "store_template",   o);

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
            gd_set_get(&gd_sets[SET_TOPICS], "topic", i, o);
        }
        else
        if (strcmp(cmd, "store_topic") == 0) {
            topics = cmd_set_store(topics, "id", i, o);
        }
        else
        if (strcmp(cmd, "topics") == 0) {
            gd_set_list_write(&gd_sets[SET_TOPICS], i, o);
        }
        else
        if (strcmp(cmd, "user") == 0) {
            gd_set_get(&gd_sets[SET_USERS], "user", i, o);
        }
        else
        if (strcmp(cmd, "store_user") == 0) {
            users = cmd_set_store(users, "id", i, o);
        }
        else
        if (strcmp(cmd, "users") == 0) {
            gd_set_list_write(&gd_sets[SET_USERS], i, o);
        }
        else
        if (strcmp(cmd, "template") == 0) {
            gd_set_get(&gd_sets[SET_TEMPLATES], "template", i, o);
        }
        else
        if (strcmp(cmd, "store_template") == 0) {
            templates = cmd_set_store(templates, "id", i, o);
        }
        else
        if (strcmp(cmd, "templates") == 0) {
            gd_set_list_write(&gd_sets[SET_TEMPLATES], i, o);
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


void grutad_init(void)
{
    int n;

    for (n = 0; n < SET_NUM; n++)
        gd_set_init(&gd_sets[n]);
}


int main(int argc, char *argv[])
{
    FILE *f;

    grutad_init();

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
