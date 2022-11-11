create or replace package dd_util is
   /*
   * Copyright 2011-2017 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
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

   /** 
   * data dictionary utility package
   *
   * @headcom
   */
   
   /**
   * Resolves the synonym of a given object.
   * If the given object is not a synonym the fully qualified object is returned.
   *
   * @param in_parse_user parsing user
   * @param in_obj partially qualified object (synonym)
   * @param in_in_depth resolve synonym chains in depth? 1=true (default), 0=false
   * @returns fully qualifed object
   */
   function resolve_synonym(
      in_parse_user in varchar2,
      in_obj        in obj_type,
      in_in_depth   in number default 1
   ) return obj_type;

   /**
   * Gets the fully qualified object.
   *
   * @param in_parse_user parsing schema
   * @param in_obj partially qualified object
   * @param in_namespace the namespace where the object must be found (default: 1)
   * @returns fully qualifed object
   */
   function get_object(
      in_parse_user in varchar2,
      in_obj        in obj_type,
      in_namespace  in number default 1
   ) return obj_type;
   
   /**
   * Gets fully qualified objects.
   * Returns objects found in the data dictionary only.
   * Removes duplicates.
   *
   * @param in_parse_user parsing user
   * @param in_t_obj list of partially qualified objects
   * @param in_namespace the namespace where the objects must be found (default: 1)
   * @returns table of objects
   */
   function get_objects(
      in_parse_user in varchar2,
      in_t_obj      in t_obj_type,
      in_namespace  in number default 1
   ) return t_obj_type;
   
   /**
   * Gets the column id of a view or table column.
   *
   * @param in_owner owner of the object_name
   * @param in_object_name view or table name
   * @param in_column_name column name to get id for
   * @returns column_id (position in the view)
   */
   function get_column_id(
      in_owner       in varchar2,
      in_object_name in varchar2,
      in_column_name in varchar2
   ) return integer;
   
   /**
   * Gets the view source (query) of a given view.
   * 
   * @param in_obj fully qualified object 
   * @returns source of the view as CLOB
   */
   function get_view_source(
      in_obj in obj_type
   ) return clob;

end dd_util;
/
