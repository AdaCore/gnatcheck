--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with GNAT.OS_Lib;

with Lkql_Checker.String_Utilities; use Lkql_Checker.String_Utilities;

package body Lkql_Checker.File_Utilities is

   -----------------
   -- URI_To_Path --
   -----------------

   function URI_To_Path (URI : String) return String is
      Prefix          : constant String := "file://";
      Unix_Style_Path : constant String :=
        (if Has_Prefix (URI, Prefix)
         then URI (URI'First + Prefix'Length .. URI'Last)
         else URI);
      Is_Absolute     : constant Boolean := Has_Prefix (Unix_Style_Path, "/");
   begin
      if GNAT.OS_Lib.Directory_Separator = '\' then
         --  Handle the case where we're on a Windows system
         return
           Replace_Char
             ((if Is_Absolute
               then
                 --  Remove the first "/" because absolute paths on Windows
                 --  start with the drive letter.
                 Unix_Style_Path
                   (Unix_Style_Path'First + 1 .. Unix_Style_Path'Last)
               else Unix_Style_Path),
              '/',
              "\");
      else
         return Unix_Style_Path;
      end if;
   end URI_To_Path;

end Lkql_Checker.File_Utilities;
