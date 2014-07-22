#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include <pthread.h>
#include <semaphore.h>

#define PROTO_VERSION   "0.11"
#define SERVER_VERSION  "0.0"


/** gd values **/

struct gd_val {
    char *k;
    struct gd_val *v;
    struct gd_val *n;
};


static struct gd_val *gd_val_free(struct gd_val *o)
{
    if (o) {
        free(o->k);
        gd_val_free(o->v);
        gd_val_free(o->n);

        free(o);
    }

    return NULL;
}


static struct gd_val *gd_val_new(char *k, struct gd_val *v, struct gd_val *n)
{
    struct gd_val *o = (struct gd_val *)malloc(sizeof(*o));

    o->k = k;
    o->v = v;
    o->n = n;

    return o;
}


static struct gd_val *gd_val_get(struct gd_val *o, char *k)
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


static struct gd_val *gd_val_get_i(struct gd_val *o, char *k)
{
    if (o) {
        int i = strcmp(k, o->k);

        if (i > 0)
            o = NULL;
        else
        if (i < 0)
            o = gd_val_get_i(o->n, k);
    }

    return o;
}


static struct gd_val *gd_val_set(struct gd_val *o, char *k, struct gd_val *v)
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


static struct gd_val *gd_val_set_r(struct gd_val *o, char *k, struct gd_val *v)
{
    if (o) {
        int i = strcmp(k, o->k);

        if (i <= 0)
            o = gd_val_new(k, v, o);
        else
            o->n = gd_val_set_r(o->n, k, v);
    }
    else
        o = gd_val_new(k, v, NULL);

    return o;
}


static struct gd_val *gd_val_set_i(struct gd_val *o, char *k, struct gd_val *v)
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
        if (i > 0)
            o = gd_val_new(k, v, o);
        else
            o->n = gd_val_set_i(o->n, k, v);
    }
    else
        o = gd_val_new(k, v, NULL);

    return o;
}


static struct gd_val *gd_val_append(struct gd_val *o, char *k, struct gd_val *v)
{
    if (o)
        o->n = gd_val_append(o->n, k, v);
    else
        o = gd_val_new(k, v, NULL);

    return o;
}


static struct gd_val *gd_val_delete(struct gd_val *o, char *k)
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


/** grutad net proto **/

#define POKE_STEP 16

static char *line_poke(char *s, int c, size_t *z, off_t *n)
{
    if (*z == *n) {
        *z += POKE_STEP;
        s = realloc(s, *z);
    }

    s[(*n)++] = c;

    return s;
}


static char *line_read(FILE *f)
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


static struct gd_val *obj_read(FILE *i, FILE *o)
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



static struct gd_val *list_read(FILE *i, FILE *o, int *n)
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



static char *arg_read(FILE *i, FILE *o)
{
    fprintf(o, "OK ready to receive argument\n");

    return line_read(i);
}


static void list_write(struct gd_val *l, FILE *i, FILE *o)
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


static void obj_write(struct gd_val *l, FILE *o, FILE *p)
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


struct gd_val *about            = NULL;
struct gd_set *topics           = NULL;
struct gd_set *users            = NULL;
struct gd_set *sessions         = NULL;
struct gd_set *templates        = NULL;
struct gd_set *stories          = NULL;
struct gd_set *stories_by_date  = NULL;

/** gd sets **/

struct gd_set {
    char            *name;
    sem_t           sem;
    pthread_mutex_t mutex;
    struct gd_val   *set;
};

int gd_max_threads = 256;


/** sets **/

static struct gd_set *gd_set_new(char *name)
{
    struct gd_set *s;

    s = (struct gd_set *)malloc(sizeof(*s));

    s->name = name;
    sem_init(&s->sem, 0, gd_max_threads);
    pthread_mutex_init(&s->mutex, NULL);
    s->set = NULL;

    return s;
}


enum {
    UNLOCK_RO,
    UNLOCK_RW,
    LOCK_RO,
    LOCK_RW
};

static void gd_set_lock(struct gd_set *s, int type)
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


static void gd_set_dump(struct gd_set *s, FILE *o)
{
    struct gd_val *v;

    gd_set_lock(s, LOCK_RO);

    v = s->set;
    while (v) {
        fprintf(o, "store_%s\n", s->name);
        obj_write(v->v, o, NULL);
        v = v->n;
    }

    gd_set_lock(s, UNLOCK_RO);
}


static void gd_set_list_write(struct gd_set *s, FILE *i, FILE *o)
{
    gd_set_lock(s, LOCK_RO);

    list_write(s->set, i, o);

    gd_set_lock(s, UNLOCK_RO);
}


static void gd_set_get(struct gd_set *s, FILE *i, FILE *o)
{
    struct gd_val *obj;
    char *a;

    a = arg_read(i, o);

    gd_set_lock(s, LOCK_RO);

    if ((obj = gd_val_get(s->set, a)) != NULL) {
        obj_write(obj->v, o, o);
    }
    else
        fprintf(o, "ERROR %s %s not found\n", a, s->name);

    gd_set_lock(s, UNLOCK_RO);

    free(a);
}


static char *gd_pk_build(struct gd_val *o, char **pks, int *l)
{
    struct gd_val *key;
    char *pk = NULL;
    int n = 0, c;

    *l = 0;

    while (*pks && (key = gd_val_get(o, *pks)) != NULL) {
        c = strlen(key->v->k);
        pk = realloc(pk, n + c + 2);
        strcpy(&pk[n], key->v->k);

        (*l)++;
        pks++;

        if (*pks) {
            pk[n + c] = '/';
            pk[n + c + 1] = '\0';
        }

        n += c + 1;
    }

    return pk;
}


static char *gd_pk_complete(struct gd_val *s, char *ppk)
{
    char tmp[32];
    char *npk = strdup(ppk);

    sprintf(tmp, "%c%06x%c",
        (char) ('a' + random() % 28),
        (int) (random() & 0xffffff),
        (char) ('a' + random() % 28)
    );

    npk = realloc(npk, strlen(npk) + strlen(tmp) + 1);
    strcat(npk, tmp);

    if (gd_val_get(s, npk) == NULL)
        free(ppk);
    else {
        free(npk);
        npk = gd_pk_complete(s, ppk);
    }

    return npk;
}


static void gd_set_store_v(struct gd_set *s, char **pks, int n, FILE *i, FILE *o)
{
    struct gd_val *obj;
    char *pk;
    int m;

    obj = obj_read(i, o);
    pk = gd_pk_build(obj, pks, &m);

    if (m >= n) {
        gd_set_lock(s, LOCK_RW);

        s->set = gd_val_set(s->set, pk, obj);

        gd_set_lock(s, UNLOCK_RW);

        fprintf(o, "OK %s stored\n", pk);
    }
    else {
        fprintf(o, "ERROR %s pk not found\n", s->name);
        free(pk);
        gd_val_free(obj);
    }
}


static void gd_set_store_story(FILE *i, FILE *o)
{
    struct gd_val *obj;
    char *pk;
    int m;
    char *pks[] = { "topic_id", "id", NULL };

    obj = obj_read(i, o);
    pk = gd_pk_build(obj, pks, &m);

    if (m > 0) {
        struct gd_val *obj_t;

        gd_set_lock(stories, LOCK_RW);

        if (m == 1)
            pk = gd_pk_complete(stories->set, pk);

        if ((obj_t = gd_val_get(stories->set, pk)) != NULL) {
            /* dequeue story from indexes */
            /* ... */
        }

        stories->set = gd_val_set(stories->set, pk, obj);

        gd_set_lock(stories, UNLOCK_RW);

        if ((obj_t = gd_val_get(obj, "date")) != NULL) {
            char *s_date = obj_t->v->k;

            gd_set_lock(stories_by_date, LOCK_RW);

            if ((obj_t = gd_val_get_i(stories_by_date->set, s_date)) == NULL) {
                stories_by_date->set =
                    gd_val_set_i(stories_by_date->set, s_date,
                                gd_val_new(strdup(pk), NULL, NULL));
            }
            else {
                obj_t->v = gd_val_set_i(obj_t->v, strdup(pk), NULL);
            }

            gd_set_lock(stories_by_date, UNLOCK_RW);
        }

        fprintf(o, "OK %s story stored\n", pk);
    }
    else {
        fprintf(o, "ERROR story pk not found\n");
        free(pk);
        gd_val_free(obj);
    }
}


static void gd_set_store(struct gd_set *s, FILE *i, FILE *o)
{
    char *pks[] = { "id", NULL };

    gd_set_store_v(s, pks, 1, i, o);
}


static void gd_set_delete(struct gd_set *s, FILE *i, FILE *o)
{
    char *a;

    a = arg_read(i, o);

    gd_set_lock(s, LOCK_RW);

    s->set = gd_val_delete(s->set, a);

    gd_set_lock(s, UNLOCK_RW);

    fprintf(o, "OK deleted\n");

    free(a);
}


static void gd_story_set(FILE *i, FILE *o)
{
    struct gd_val *obj;
    struct gd_val *p;
    int c, max;
    char *from, *to, *order;
    struct gd_val *order_s = NULL;

    c       = 0;
    max     = 0x7fffffff;
    from    = NULL;
    to      = NULL;
    order   = NULL;

    obj = obj_read(i, o);

    if ((p = gd_val_get(obj, "num")) != NULL) {
        sscanf(p->v->k, "%d", &max);
    }
    if ((p = gd_val_get(obj, "offset")) != NULL) {
        sscanf(p->v->k, "%d", &c);
        c *= -1;
    }
    if ((p = gd_val_get(obj, "from")) != NULL) {
        from = p->v->k;
    }
    if ((p = gd_val_get(obj, "to")) != NULL) {
        to = p->v->k;
    }
    if ((p = gd_val_get(obj, "order")) != NULL && strcmp(p->v->k, "date") != 0) {
        order = p->v->k;
    }

    gd_set_lock(stories_by_date, LOCK_RO);

    fprintf(o, "OK list follows\n");

    for (p = stories_by_date->set; c < max && p; p = p->n) {
        struct gd_val *sp;
        struct gd_val *story;

        if (from && strcmp(from, p->k) > 0)
            break;

        if (to && strcmp(to, p->k) < 0)
            continue;

        for (sp = p->v; c < max && sp; sp = sp->n, c++) {
            if (c >= 0) {
                if (order) {
                    struct gd_val *v;

                    gd_set_lock(stories, LOCK_RO);
                    story = gd_val_get(stories->set, sp->k);
                    gd_set_lock(stories, UNLOCK_RO);

                    if (story && (v = gd_val_get(story->v, order)) != NULL) {
                        order_s = gd_val_set_r(order_s, v->v->k, gd_val_new(sp->k, NULL, NULL));
                    }
                    else
                        printf("no se\n");
                }
                else {
                    fprintf(o, "%s/%s\n", p->k, sp->k);
                }
            }
        }
    }

    if (order_s) {
        for (p = order_s; p; p = p->n) {
            fprintf(o, ">>> %s\n", p->v->k);
        }

        gd_val_free(order_s);
    }

    fprintf(o, ".\n");

    gd_set_lock(stories_by_date, UNLOCK_RO);

    gd_val_free(obj);
}


static void dump(FILE *o)
{
    gd_set_dump(topics,     o);
    gd_set_dump(users,      o);
    gd_set_dump(templates,  o);
    gd_set_dump(stories,    o);

    fprintf(o, "bye\n");
}


static void dialog(FILE *i, FILE *o)
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
            gd_set_get(topics, i, o);
        }
        else
        if (strcmp(cmd, "store_topic") == 0) {
            gd_set_store(topics, i, o);
        }
        else
        if (strcmp(cmd, "topics") == 0) {
            gd_set_list_write(topics, i, o);
        }
        else
        if (strcmp(cmd, "user") == 0) {
            gd_set_get(users, i, o);
        }
        else
        if (strcmp(cmd, "store_user") == 0) {
            gd_set_store(users, i, o);
        }
        else
        if (strcmp(cmd, "users") == 0) {
            gd_set_list_write(users, i, o);
        }
        else
        if (strcmp(cmd, "template") == 0) {
            gd_set_get(templates, i, o);
        }
        else
        if (strcmp(cmd, "store_template") == 0) {
            gd_set_store(templates, i, o);
        }
        else
        if (strcmp(cmd, "templates") == 0) {
            gd_set_list_write(templates, i, o);
        }
        else
        if (strcmp(cmd, "store_story") == 0) {
            gd_set_store_story(i, o);
        }
        else
        if (strcmp(cmd, "delete_story") == 0) {
            gd_set_delete(stories, i, o);
        }
        else
        if (strcmp(cmd, "story") == 0) {
            gd_set_get(stories, i, o);
        }
        else
        if (strcmp(cmd, "story_set") == 0) {
            gd_story_set(i, o);
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


static void grutad_init(void)
{
    about = gd_val_set(about, strdup("proto_version"),  gd_val_new(strdup(PROTO_VERSION), NULL, NULL));
    about = gd_val_set(about, strdup("server_version"), gd_val_new(strdup(SERVER_VERSION), NULL, NULL));
    about = gd_val_set(about, strdup("server_id"),      gd_val_new(strdup("grutad.c"), NULL, NULL));

    topics          = gd_set_new("topic");
    users           = gd_set_new("user");
    sessions        = gd_set_new("session");
    templates       = gd_set_new("template");
    stories         = gd_set_new("story");
    stories_by_date = gd_set_new("stories_by_date");
}


int main(int argc, char *argv[])
{
    FILE *f;

    grutad_init();

    if ((f = fopen("dump.bin", "r")) != NULL) {
        dialog(f, stdout);
        fclose(f);
    }

    dialog(stdin, stdout);

    return 0;
}
