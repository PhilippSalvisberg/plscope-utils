CREATE OR REPLACE PACKAGE dd_util IS
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
   * @returns fully qualifed object
   */
   FUNCTION resolve_synonym (
      in_parse_user IN VARCHAR2,
      in_obj        IN obj_type
   ) return obj_type;

   /**
   * Gets the fully qualified object.
   *
   * @param in_parse_user parsing user
   * @param in_obj partially qualified object
   * @returns fully qualifed object
   */
   FUNCTION get_object(
      in_parse_user IN VARCHAR2, 
      in_obj        IN obj_type
   ) RETURN obj_type;
   
   /**
   * Gets fully qualified objects.
   * Returns objects found in the data dictionary only.
   * Removes duplicates.
   *
   * @param in_parse_user parsing user
   * @param in_t_obj list of partially qualified objects
   * @returns table of objects
   */
   FUNCTION get_objects(
      in_parse_user IN VARCHAR2,
      in_t_obj      IN t_obj_type
   ) RETURN t_obj_type;
   
   /**
   * Gets the column id of a view or table column.
   *
   * @param in_owner owner of the object_name
   * @param in_object_name view or table name
   * @param in_column_name column name to get id for
   * @returns column_id (position in the view)
   */
   FUNCTION get_column_id(
      in_owner       IN VARCHAR2,
      in_object_name IN VARCHAR2,
      in_column_name IN VARCHAR2
   ) RETURN INTEGER;
   
   /**
   * Gets the view source (query) of a given view.
   * 
   * @param in_obj fully qualified object 
   * @returns source of the view as CLOB
   */
   FUNCTION get_view_source(
      in_obj IN obj_type
   ) RETURN CLOB;
      
END dd_util;
/
