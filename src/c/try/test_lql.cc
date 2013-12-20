// Copyright 2013 (c) Diego Souza <dsouza@c0d3.xxx>
//  
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//  
//     http://www.apache.org/licenses/LICENSE-2.0
//  
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <cstdlib>
#include <string.h>
#include <unistd.h>
#include <UnitTest++.h>
#include "leela/lql.h"
#include "leela/naming.h"
#include "leela/string.h"
#include "leela/endpoint.h"

TEST(test_leela_make_elem)
{
 leela_endpoint_t *endpoint[] = {leela_endpoint_load(getenv("LEELA_ENDPOINT")), NULL};
 lql_context_t *context       = leela_lql_context_init(endpoint);
 CHECK(context != NULL);
 if (context != NULL)
 {
   lql_cursor_t *cursor = leela_lql_cursor_init(context, "dgvncsz0f", "", 1000);
   leela_status rc      = leela_lql_cursor_execute(cursor, "using (testing) make (leela);");
   CHECK_EQUAL(LEELA_OK, rc);
   CHECK_EQUAL(LEELA_OK, leela_lql_cursor_close(cursor));
   CHECK_EQUAL(LEELA_OK, leela_lql_context_close(context));
 }
 leela_endpoint_free(endpoint[0]);
}

TEST(test_leela_resolve_name)
{
  leela_endpoint_t *endpoint[] = {leela_endpoint_load(getenv("LEELA_ENDPOINT")), NULL};
  lql_context_t *context       = leela_lql_context_init(endpoint);
  lql_cursor_t *cursor;

  cursor = leela_lql_cursor_init(context, "dgvncsz0f", "", 1000);
  CHECK_EQUAL(LEELA_OK, leela_lql_cursor_execute(cursor, "using (testing) make (leela);"));
  CHECK_EQUAL(LEELA_EOF, leela_lql_cursor_next(cursor));
  CHECK_EQUAL(LEELA_OK, leela_lql_cursor_close(cursor));

  cursor = leela_lql_cursor_init(context, "dgvncsz0f", "", 1000);
  CHECK_EQUAL(LEELA_OK, leela_lql_cursor_execute(cursor, "using (testing) name 0x2242b7b65b677c562ec89a989ed132e384e01a7b0d1241246ea891e6;"));
  CHECK_EQUAL(LEELA_OK, leela_lql_cursor_next(cursor));
  CHECK_EQUAL(LQL_NAME_MSG, leela_lql_fetch_type(cursor));
  lql_name_t *name = leela_lql_fetch_name(cursor);
  CHECK(name != NULL);
  CHECK_EQUAL("dgvncsz0f", name->user);
  CHECK_EQUAL("testing", name->tree);
  CHECK_EQUAL("leela", name->name);
  leela_lql_name_free(name);
  CHECK_EQUAL(LEELA_EOF, leela_lql_cursor_next(cursor));
  CHECK_EQUAL(LEELA_OK, leela_lql_cursor_close(cursor));
  
  CHECK_EQUAL(LEELA_OK, leela_lql_context_close(context));
  leela_endpoint_free(endpoint[0]);
}

TEST(test_leela_resolve_path)
{
  leela_endpoint_t *endpoint[] = {leela_endpoint_load(getenv("LEELA_ENDPOINT")), NULL};
 lql_context_t *context        = leela_lql_context_init(endpoint);
 lql_cursor_t *cursor;

 cursor = leela_lql_cursor_init(context, "dgvncsz0f", "", 1000);
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_execute(cursor, "using (testing) make (leela), make (module), make (warpdrive), make (blackbox);"));
 CHECK_EQUAL(LEELA_EOF, leela_lql_cursor_next(cursor));
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_close(cursor));

 cursor = leela_lql_cursor_init(context, "dgvncsz0f", "", 1000);
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_execute(cursor, "using (testing) make (leela) -[module]> (warpdrive) -[module]> (blackbox);"));
 CHECK_EQUAL(LEELA_EOF, leela_lql_cursor_next(cursor));
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_close(cursor));

 cursor = leela_lql_cursor_init(context, "dgvncsz0f", "", 1000);
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_execute(cursor, "using (testing) path (leela) -[module]> () -[module]> ();"));
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_next(cursor));
 CHECK_EQUAL(LQL_PATH_MSG, leela_lql_fetch_type(cursor));
 lql_path_t *path = leela_lql_fetch_path(cursor);
 CHECK(path != NULL);
 CHECK_EQUAL(2, path->size);
 CHECK_EQUAL("module", path->entries[0].fst);
 CHECK_EQUAL("0x17a47529e3f5398fbbdec1831fcfdb102f6c5b3cf1f0a127db7a916d", path->entries[0].snd);
 CHECK_EQUAL("module", path->entries[1].fst);
 CHECK_EQUAL("0x77ba03cf506747085f8952200ed916a5761009051845a7c308f3b014", path->entries[1].snd);
 leela_lql_path_free(path);
 CHECK_EQUAL(LEELA_EOF, leela_lql_cursor_next(cursor));
 CHECK_EQUAL(LEELA_OK, leela_lql_cursor_close(cursor));

 CHECK_EQUAL(LEELA_OK, leela_lql_context_close(context));
 leela_endpoint_free(endpoint[0]);
}
