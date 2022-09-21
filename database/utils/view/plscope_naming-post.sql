/*
* Copyright 2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

-- Post-creation actions on the plscope_naming view:
--   1. Re-create the view, with the text of the view comment inlined
--      after the initial "with" keyword
--   2. Rewrite the view comment, in a lighter form without the "/*",
--      "*", and "*/" markers
declare
   co_view_name   constant user_views.view_name %type := 'PLSCOPE_NAMING';
   co_trim_chars  constant varchar2(2 char) := ' ' || chr(10);

   l_view_src     long; -- NOSONAR: G-2510
   l_view_text    clob;

   l_comment_text varchar2(4000 byte);
begin
   select v.text into l_view_src -- NOSONAR: G-2510
     from user_views v
    where v.view_name = co_view_name;
   l_view_text := l_view_src;    -- NOSONAR: G-2510

   select c.comments into l_comment_text
     from user_tab_comments c
    where c.table_name = co_view_name
      and c.table_type = 'VIEW';

   execute immediate 'create or replace view ' || co_view_name || ' as '
      || regexp_substr(l_view_text, '^with\s*$', 1, 1, 'm')
      || rtrim(l_comment_text, co_trim_chars)
      || regexp_replace(l_view_text, '^with\s*$', '', 1, 1, 'm');

   execute immediate 'comment on table ' || co_view_name || ' is q''#'
      || rtrim(ltrim(regexp_replace(l_comment_text, '^...?', '', 1, 0, 'm'),
                     co_trim_chars), co_trim_chars)
      || '#''';
end;
/
