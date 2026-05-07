--
--  Copyright (C) 2005-2026, AdaCore
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Directories; use Ada.Directories;

with Lkql_Checker.Options;      use Lkql_Checker.Options;
with Lkql_Checker.Source_Table; use Lkql_Checker.Source_Table;

with GNATCOLL.Strings; use GNATCOLL.Strings;

package body Lkql_Checker.Diagnostics is

   ---------
   -- "<" --
   ---------

   function "<" (L, R : Diagnostic) return Boolean is
   begin
      return
        L.File < R.File
        or else (L.File = R.File and then L.Sloc < R.Sloc)
        or else (L.File = R.File
                 and then L.Sloc = R.Sloc
                 and then L.Text < R.Text);
   end "<";

   ----------------
   -- Sloc_Image --
   ----------------

   function Sloc_Image (Line, Column : Natural) return String is
      Line_Image : constant String := Line'Image;
      Col_Image  : constant String := Column'Image;
   begin
      if Column < 10 then
         return
           Line_Image (2 .. Line_Image'Last)
           & ":0"
           & Col_Image (2 .. Col_Image'Last);
      else
         return
           Line_Image (2 .. Line_Image'Last)
           & ":"
           & Col_Image (2 .. Col_Image'Last);
      end if;
   end Sloc_Image;

   function Sloc_Image (Sloc : Source_Location) return String is
   begin
      return Sloc_Image (Natural (Sloc.Line), Natural (Sloc.Column));
   end Sloc_Image;

   ----------------------
   -- Store_Diagnostic --
   ----------------------

   procedure Store_Diagnostic
     (Collector : in out Diagnostic_Collector;
      Text      : String;
      Kind      : Diagnostic_Kind;
      SF        : SF_Id;
      Rule      : Rule_Id := No_Rule_Id;
      Instance  : Rule_Instance_Access := null)
   is
      Matches : Match_Array (0 .. 5);
      Sloc    : Source_Location;
   begin
      Match (Match_Diagnostic, Text, Matches);

      pragma
        Assert
          (Matches (0) /= No_Match, "Invalid text for diagnostic: " & Text);

      Sloc.Line :=
        Line_Number'Value (Text (Matches (3).First .. Matches (3).Last));
      Sloc.Column :=
        Column_Number'Value (Text (Matches (4).First .. Matches (4).Last));

      Store_Diagnostic
        (Collector,
         Full_File_Name => Text (Matches (1).First .. Matches (1).Last),
         Sloc           => Sloc,
         Message        => Text (Matches (5).First .. Matches (5).Last),
         Kind           => Kind,
         SF             => SF,
         Rule           => Rule,
         Instance       => Instance);
   end Store_Diagnostic;

   procedure Store_Diagnostic
     (Collector      : in out Diagnostic_Collector;
      Full_File_Name : String;
      Message        : String;
      Sloc           : Source_Location;
      Kind           : Diagnostic_Kind;
      SF             : SF_Id;
      Rule           : Rule_Id := No_Rule_Id;
      Instance       : Rule_Instance_Access := null)
   is
      File_Name : constant Unbounded_String :=
        To_Unbounded_String
          (if Tool_Args.Full_Source_Locations.Get
           then Full_File_Name
           else Simple_Name (Full_File_Name));
      Tmp       : Diagnostic :=
        (Text          => To_Unbounded_String (Message),
         Sloc          => Sloc,
         File          => File_Name,
         Justification => Null_Unbounded_String,
         Kind          => Kind,
         Rule          => Rule,
         Instance      => Instance,
         SF            => SF);
   begin
      --  We need this check to avoid diagnostics duplication. Our set
      --  container has broken "<" relation, so Insert may add diagnostics
      --  that are already stored in the container (see the documentation
      --  for "<" for more details).
      if not Collector.All_Error_Messages.Contains (Tmp) then
         if Kind = Compiler_Error then
            Set_Source_Status (SF, Not_A_Legal_Source);
         elsif Kind = Internal_Error then
            Set_Source_Status (SF, Error_Detected);
         end if;
         Collector.All_Error_Messages.Insert (Tmp);
      end if;
   end Store_Diagnostic;

end Lkql_Checker.Diagnostics;
