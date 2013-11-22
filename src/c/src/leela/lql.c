#include "lql.h"

#define DEBUG 1

struct context_t    { void * ctx; };
struct cursor_t     { void * cur; };
static char * channel;
static int sock_closed = 0;
static int res = 0;
static int timeout = -1;

void leela_lql_debug(const char *prefix, int size, const char *ss){
    if (DEBUG){ fprintf(stderr, "[LIB DEBUG] %s %.*s\n", prefix, size, ss); }
}

void show_error(const char *file, int line){
    char * buf = (char *)malloc(sizeof(char)*(strlen(file) + 16));
    sprintf(buf, "%s:%d:LQL ERROR", file, line);
    perror(buf);
    if(buf != NULL){
        free(buf);
        buf = NULL;
    }
}

int drop_connection(const char *file, int line){
    show_error(file, line);
    sock_closed = 1;
    return(-1);
}

int leela_lql_send(struct cursor_t *cur, const char *s, int flags){
    if (!sock_closed){
        leela_lql_debug(">", strlen(s), s);
        size_t size = zmq_send(cur->cur, s, strlen(s), flags);
        if (size == -1){ return(drop_connection(__FILE__, __LINE__)); }
        return(size);
    }
    return(-1);
}

const char *leela_lql_auth(void){
    const char *key = "usertest:0:0 0";
    return(key);
}

size_t get_msg(struct cursor_t *cur, zmq_msg_t *message){
    size_t size = 0;

    if (zmq_msg_init (message) == -1){ return(drop_connection(__FILE__, __LINE__)); }

    if (zmq_setsockopt(cur->cur, ZMQ_RCVTIMEO, &timeout, sizeof(timeout)) == -1){
        return(drop_connection(__FILE__, __LINE__));
    }

    size = zmq_msg_recv (message, cur->cur, 0);
    if (size == -1){ return(EXIT_SUCCESS); }

    return(size);
}

size_t get_data(struct cursor_t *cur, zmq_msg_t *message, char **msg){
    size_t size = 0;

    if (zmq_msg_close(message) == -1){ return(drop_connection(__FILE__, __LINE__)); }

    size = get_msg(cur, message);
    *msg = zmq_msg_data(message);
    leela_lql_debug("<", size, *msg);

    return(size);
}

int set_field(struct cursor_t *cur, zmq_msg_t *message, char **msg, char **field){
    size_t size = get_data(cur, message, msg);

    *field = (char *)malloc(sizeof(char)*(size + 1));

    if(*field == NULL){ return(drop_connection(__FILE__, __LINE__)); }
    strncpy(*field, *msg, size);
    (*field)[size] = '\0';

    return(EXIT_SUCCESS);
}

struct context_t *leela_context_init(){
    struct context_t *ctx = (struct context_t *)malloc(sizeof(struct context_t));
    if(ctx == NULL){
        show_error(__FILE__, __LINE__);
        return(NULL);
    }

    ctx->ctx = zmq_ctx_new();

    if(ctx->ctx == NULL){
        show_error(__FILE__, __LINE__);
        return(NULL);
    }
    return(ctx);
}

struct cursor_t *leela_cursor_init(struct context_t *ctx, const char *endpoint){
    struct cursor_t *cur =  (struct cursor_t *)malloc(sizeof(struct cursor_t));
    if(cur == NULL){
        show_error(__FILE__, __LINE__);
        return(NULL);
    }
    cur->cur = zmq_socket (ctx->ctx, ZMQ_REQ);
    if(cur->cur == NULL){
        show_error(__FILE__, __LINE__);
        return(NULL);
    }
    sock_closed = 0;

    if (zmq_connect(cur->cur, endpoint) == -1){
        show_error(__FILE__, __LINE__);
        sock_closed = 1;
        return(NULL);
    }
    return(cur);
}

int leela_lql_execute(struct cursor_t *cur, const char * query){
    size_t size = 0;
    int more;
    size_t more_size = sizeof (more);
    char *msg  = NULL;
    zmq_msg_t message;

    if (leela_lql_send(cur, leela_lql_auth(), ZMQ_SNDMORE) < 0) return(drop_connection(__FILE__, __LINE__));
    if (leela_lql_send(cur, "begin", ZMQ_SNDMORE) < 0) return(drop_connection(__FILE__, __LINE__));
    if (leela_lql_send(cur, query, 0) < 0) return(drop_connection(__FILE__, __LINE__));

    size = get_msg(cur, &message);
    msg  = zmq_msg_data(&message);
    msg[size] = '\0';
    leela_lql_debug("<", size, msg);

    if (strncmp(msg, "done", size) != 0){
        if (strncmp(msg, "fail", size) == 0){
            do{
                size = zmq_msg_recv (&message, cur->cur, 0);
                if (size == -1){ return(drop_connection(__FILE__, __LINE__)); }
                msg  = zmq_msg_data(&message);
                leela_lql_debug("<", size, msg);

                if (zmq_getsockopt (cur->cur, ZMQ_RCVMORE, &more, &more_size) == -1){
                    return(drop_connection(__FILE__, __LINE__));
                }
            }while(more);
            sock_closed = 1;
        }
        else return(drop_connection(__FILE__, __LINE__));
    }
    else{
        if (channel == NULL){
            if (zmq_getsockopt (cur->cur, ZMQ_RCVMORE, &more, &more_size) == -1){
                return(drop_connection(__FILE__, __LINE__));
            }
            if(more){
                size = zmq_msg_recv (&message, cur->cur, 0);
                if (size == -1){ return(drop_connection(__FILE__, __LINE__)); }

                channel = (char *)malloc(sizeof(char)*(size + 1));
                if(channel == NULL){ return(drop_connection(__FILE__, __LINE__)); }
                strncpy(channel, zmq_msg_data(&message), size);
                channel[size] = '\0';
            }
            else { return(drop_connection(__FILE__, __LINE__)); }
        }
        leela_lql_debug("<", size, channel);
        return(EXIT_SUCCESS);
    }

    if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }
    return(EXIT_SUCCESS);
}

int leela_next(struct cursor_t *cur, row_t *row){
    size_t size = 0;
    int more;
    size_t more_size = sizeof (more);
    char *msg  = NULL;
    zmq_msg_t message;

    do{
        size = get_msg(cur, &message);
        msg = zmq_msg_data(&message);
        leela_lql_debug("<", size, msg);

        if (zmq_getsockopt (cur->cur, ZMQ_RCVMORE, &more, &more_size) == -1){
            res = drop_connection(__FILE__, __LINE__);
            more = 0;
        }

        if (strncmp(msg, "done", size) == 0){
            if (!more){
                row->row_type = END;
                res = EXIT_SUCCESS;
            }
            else{
                if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }
                res = leela_next(cur, row);
                if (res == -1){ return(drop_connection(__FILE__, __LINE__)); }
                more = 0;
                return(res);
            }
        }
        else if (strncmp(msg, "item", size) == 0){
            if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            res = leela_next(cur, row);
            if (res == -1){ return(drop_connection(__FILE__, __LINE__)); }
            return(res);
        }
        else if (strncmp(msg, "list", size) == 0){
            char *length = NULL;
            if(set_field(cur, &message, &msg, &length) == -1){ return(drop_connection(__FILE__, __LINE__)); }

            if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }

            res = leela_next(cur, row);
            if (res == -1){ return(drop_connection(__FILE__, __LINE__)); }
            res += atoi(length);
            free(length);
            return(res);
        }
        else if (strncmp(msg, "path", size) == 0){
            char *length = NULL;

            row->row_type = PATH;
            if(set_field(cur, &message, &msg, &length) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            res += (atoi(length) / 2 + atoi(length) % 2);

            if(set_field(cur, &message, &msg, &(row->path.label)) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            if(set_field(cur, &message, &msg, &(row->path.guid)) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            res -= 1;
            more = 0;
            free(length);
            if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            return(res);
        }
        else if (strncmp(msg, "name", size) == 0){
            row->row_type = NAME;
            if(set_field(cur, &message, &msg, &row->name.user) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            if(set_field(cur, &message, &msg, &row->name.tree) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            if(set_field(cur, &message, &msg, &row->name.name) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            more = 0;
            if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }
            return(res);
        }
        else if (strncmp(msg, "fail", size) == 0){
            do{
                size = get_data(cur, &message, &msg);
                zmq_getsockopt (cur->cur, ZMQ_RCVMORE, &more, &more_size);
            }while(more);

            res = drop_connection(__FILE__, __LINE__);
            more = 0;
        }
        else{
            res = drop_connection(__FILE__, __LINE__);
            more = 0;
        }

        if (zmq_getsockopt (cur->cur, ZMQ_RCVMORE, &more, &more_size) == -1){
            res = drop_connection(__FILE__, __LINE__);
            more = 0;
        }

    }while(more);

    if (zmq_msg_close(&message) == -1){ return(drop_connection(__FILE__, __LINE__)); }
    return(res);
}

int leela_cursor_next(struct cursor_t *cur, row_t *row, int tmout){

    timeout = tmout;
    if(res == 0){
        if (leela_lql_send(cur, leela_lql_auth(), ZMQ_SNDMORE) < 0){ return(drop_connection(__FILE__, __LINE__)); }
        if (leela_lql_send(cur, "fetch", ZMQ_SNDMORE) < 0){ return(drop_connection(__FILE__, __LINE__)); }
        if (leela_lql_send(cur, channel, 0) < 0){ return(drop_connection(__FILE__, __LINE__)); }
    }

    return(leela_next(cur, row));
}

int leela_cursor_close(struct cursor_t *cur, int nowait){
    if (!sock_closed){
        if (leela_lql_send(cur, leela_lql_auth(), ZMQ_SNDMORE) < 0){ return(drop_connection(__FILE__, __LINE__)); }
        if (leela_lql_send(cur, "close", ZMQ_SNDMORE) < 0){ return(drop_connection(__FILE__, __LINE__)); }
        if(nowait){
            if (leela_lql_send(cur, channel, ZMQ_SNDMORE) < 0){ return(drop_connection(__FILE__, __LINE__)); }
            if (leela_lql_send(cur, "nowait", 0) < 0){ return(drop_connection(__FILE__, __LINE__)); }
        }
        else{
            if (leela_lql_send(cur, channel, 0) < 0){ return(drop_connection(__FILE__, __LINE__)); }
        }

        if (zmq_close(cur->cur) == -1){ return(drop_connection(__FILE__, __LINE__)); }
    }

    sock_closed = 1;
    if (channel != NULL){
        free(channel);
        channel = NULL;
    }

    if (cur != NULL){
        free(cur);
        cur = NULL;
    }
    return(EXIT_SUCCESS);
}

int leela_context_close(struct context_t *ctx){
    if (zmq_ctx_destroy(ctx->ctx) == -1){ return(drop_connection(__FILE__, __LINE__)); }
    if (ctx != NULL){
        free(ctx);
        ctx = NULL;
    }
    return(EXIT_SUCCESS);
}
