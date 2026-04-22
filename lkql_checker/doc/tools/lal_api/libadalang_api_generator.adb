pragma Ada_2022;

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Text_IO;             use Ada.Text_IO;

with Langkit_Support.Generic_API;
use Langkit_Support.Generic_API;
with Langkit_Support.Generic_API.Introspection;
use Langkit_Support.Generic_API.Introspection;
with Langkit_Support.Names;                     use Langkit_Support.Names;
with Langkit_Support.Text;                      use Langkit_Support.Text;

with Libadalang.Generic_API; use Libadalang.Generic_API;

procedure Libadalang_Api_Generator is

   --  Convert a Name_Type to its lowercase string representation
   --  (e.g. F_Body -> "f_body").
   function Name_Lower (N : Name_Type) return String
   is (To_Lower (Image (N)));

   --  Return a copy of S with all occurrences of C removed
   function Remove_Char (S : String; C : Character) return String
   is ([for Char of S when Char /= C => Char]);

   --  Camel-case a Name_Type: strip underscores, lowercase the first character
   --  (e.g. Imprecise_Fallback -> impreciseFallback).
   function Camel_Lower (N : Name_Type) return String is
      S : constant String := Remove_Char (Image (N), '_');
   begin
      if S'Length = 0 then
         return S;
      end if;
      return To_Lower (S (S'First)) & S (S'First + 1 .. S'Last);
   end Camel_Lower;

   --  Convert a display name to an RST anchor label:
   --  "AdaNode" -> "lal-adanode". Square brackets (from array type names like
   --  "List[X]") are omitted.
   function To_RST_Label (S : String) return String
   is ("lal-" & Remove_Char (Remove_Char (To_Lower (S), '['), ']'));

   function RST_Ref (Name : String) return String
   is (":ref:`" & Name & " <" & To_RST_Label (Name) & ">`");

   function RST_Code (S : String) return String
   is ("``" & S & "``");

   --  Return the display name of any Type_Ref, with underscores removed
   function Type_Display_Name (T : Type_Ref) return String is
   begin
      if Is_Node_Type (T) then
         return Remove_Char (Image (Node_Type_Name (T)), '_');
      elsif Is_Enum_Type (T) then
         return Remove_Char (Image (Enum_Type_Name (T)), '_');
      elsif Is_Array_Type (T) then
         return "List[" & Type_Display_Name (Array_Element_Type (T)) & "]";
      elsif Is_Iterator_Type (T) then
         return
           "Iterator[" & Type_Display_Name (Iterator_Element_Type (T)) & "]";
      elsif Is_Struct_Type (T) then
         return Remove_Char (Image (Struct_Type_Name (T)), '_');
      else
         case Category (T) is
            when Analysis_Unit_Category          =>
               return "AnalysisUnit";

            when Big_Int_Category | Int_Category =>
               return "Int";

            when Bool_Category                   =>
               return "Bool";

            when Char_Category | String_Category =>
               return "Str";

            when Source_Location_Category        =>
               return "SourceLocation";

            when Source_Location_Range_Category  =>
               return "SourceLocationRange";

            when Token_Category                  =>
               return "Token";

            when Symbol_Category                 =>
               return "Symbol";

            when others                          =>
               return "Unknown";
         end case;
      end if;
   end Type_Display_Name;

   --  True if the type has a dedicated section in this document
   function Has_Own_Section (T : Type_Ref) return Boolean
   is (Is_Node_Type (T)
       or else Is_Enum_Type (T)
       or else Is_Array_Type (T)
       or else Is_Struct_Type (T));

   --  Produce an inline RST reference to a type:
   --  a cross-ref link for documented types, plain code for primitives
   function Type_RST_Ref (T : Type_Ref) return String is
      Name : constant String := Type_Display_Name (T);
   begin
      if Has_Own_Section (T) then
         return RST_Ref (Name);
      else
         return RST_Code (Name);
      end if;
   end Type_RST_Ref;

   --  Print a section heading with the given underline character
   procedure Emit_Title (Title : String; Char : Character) is
   begin
      Put_Line (Title);
      Put_Line ((1 .. Title'Length => Char));
      New_Line;
   end Emit_Title;

   package String_Vectors is new
     Ada.Containers.Indefinite_Vectors
       (Index_Type   => Positive,
        Element_Type => String);
   subtype String_Vector is String_Vectors.Vector;

   function Split (S : String; Sep : Character) return String_Vector is
      Result : String_Vector;
      Start  : Positive := S'First;
   begin
      for I in S'Range loop
         if S (I) = Sep then
            Result.Append (S (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      Result.Append (S (Start .. S'Last));
      return Result;
   end Split;

   function Join (V : String_Vector; Sep : String) return String is
      Result : Unbounded_String;
   begin
      for I in V.First_Index .. V.Last_Index loop
         if I > V.First_Index then
            Append (Result, Sep);
         end if;
         Append (Result, V (I));
      end loop;
      return To_String (Result);
   end Join;

   --  Strip the common leading whitespace from all non-empty lines of Text.
   --  Doc strings from the introspection API are indented to match their
   --  enclosing Ada source, so a leading indent is always present and must
   --  be removed before the text can be used as RST content.
   function Dedent (Text : String) return String is

      --  Return S with leading spaces removed (a slice of the input).
      --  N < 0 strips all leading spaces; N >= 0 strips at most N characters.
      function Strip_Leading (S : String; N : Integer := -1) return String is
      begin
         if N < 0 then
            for I in S'Range loop
               if S (I) /= ' ' then
                  return S (I .. S'Last);
               end if;
            end loop;
            return S (S'First .. S'First - 1);
         else
            return S (S'First + Natural'Min (N, S'Length) .. S'Last);
         end if;
      end Strip_Leading;

      Lines      : constant String_Vector := Split (Text, ASCII.LF);
      Min_Indent : Natural := 0;
      Result     : String_Vector;
   begin
      --  Find the indentation of the first non-blank line; all lines in a
      --  libadalang doc string share the same base indentation.
      for Line of Lines loop
         declare
            Stripped : constant String := Strip_Leading (Line);
         begin
            if Stripped'Length > 0 then
               Min_Indent := Line'Length - Stripped'Length;
               exit;
            end if;
         end;
      end loop;
      --  Strip Min_Indent leading spaces from every line. This removes the
      --  Ada source indentation while preserving any extra indentation used
      --  within the doc string (e.g. code blocks in RST).
      for Line of Lines loop
         Result.Append (Strip_Leading (Line, Min_Indent));
      end loop;
      return Join (Result, String'(1 => ASCII.LF));
   end Dedent;

   --  Print Text with Indent prepended, preserving embedded newlines
   procedure Emit_Indented (Indent, Text : String) is
      Lines : constant String_Vector := Split (Text, ASCII.LF);
   begin
      for I in Lines.First_Index .. Lines.Last_Index loop
         if Lines (I) = "" then
            if I < Lines.Last_Index then
               New_Line;
            end if;
         else
            Put_Line (Indent & Lines (I));
         end if;
      end loop;
   end Emit_Indented;

   --  Emit a doc string if non-empty, followed by a blank line
   procedure Emit_Doc (Doc : Unbounded_Text_Type; Indent : String := "") is
      S : constant String := Dedent (To_UTF8 (To_Text (Doc)));
   begin
      if S /= "" then
         Emit_Indented (Indent, S);
         New_Line;
      end if;
   end Emit_Doc;

   --  Emit fields then properties for any struct-like type, direct members only
   procedure Emit_Members (T : Type_Ref) is
      Mems       : constant Struct_Member_Ref_Array :=
        [for M of Members (T) when Owner (M) = T => M];
      Fields     : constant Struct_Member_Ref_Array :=
        [for M of Mems when Is_Field (M) => M];
      Properties : constant Struct_Member_Ref_Array :=
        [for M of Mems when Is_Property (M) => M];
      Prefix     : constant String := Type_Display_Name (T) & ".";
   begin
      if Fields'Length > 0 then
         Put_Line (".. rubric:: Fields");
         New_Line;
      end if;
      for F of Fields loop
         Put_Line
           (".. _"
            & To_RST_Label (Prefix & Name_Lower (Member_Name (F)))
            & ":");
         New_Line;
         Put_Line (".. attribute:: " & Prefix & Name_Lower (Member_Name (F)));
         New_Line;
         Put_Line ("    :type: " & Type_RST_Ref (Member_Type (F)));
         New_Line;
         Emit_Doc (Documentation (F), "    ");
      end loop;

      if Properties'Length > 0 then
         Put_Line (".. rubric:: Properties");
         New_Line;
      end if;
      for P of Properties loop
         declare
            Last   : constant Any_Argument_Index := Member_Last_Argument (P);
            Params : String_Vector;
         begin
            for I in 1 .. Last loop
               Params.Append
                 (Camel_Lower (Member_Argument_Name (P, Argument_Index (I)))
                  & ": "
                  & Type_Display_Name
                      (Member_Argument_Type (P, Argument_Index (I))));
            end loop;
            Put_Line
              (".. _"
               & To_RST_Label (Prefix & Name_Lower (Member_Name (P)))
               & ":");
            New_Line;
            Put_Line
              (".. function:: "
               & Prefix
               & Name_Lower (Member_Name (P))
               & "("
               & Join (Params, ", ")
               & ")");
            New_Line;
            Put_Line ("    :returns: " & Type_RST_Ref (Member_Type (P)));
            New_Line;
         end;
         Emit_Doc (Documentation (P), "    ");
      end loop;
   end Emit_Members;

   procedure Emit_Header (Name : String; Title_Suffix : String := "") is
   begin
      Put_Line (".. _" & To_RST_Label (Name) & ":");
      New_Line;
      Put_Line (".. index:: " & Name);
      New_Line;
      Emit_Title (RST_Code (Name) & Title_Suffix, '"');
   end Emit_Header;

   procedure Emit_Doc_And_Members (T : Type_Ref) is
   begin
      Emit_Doc (Documentation (T));
      Emit_Members (T);
   end Emit_Doc_And_Members;

   --  Sorting infrastructure
   package TR_Vectors is new
     Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Type_Ref);

   function By_Name (A, B : Type_Ref) return Boolean
   is (Type_Display_Name (A) < Type_Display_Name (B));

   package TR_Sort is new TR_Vectors.Generic_Sorting ("<" => By_Name);

   All_T : TR_Vectors.Vector;
   Vec   : TR_Vectors.Vector;

   procedure Emit_Node_Type (T : Type_Ref) is

      procedure Emit_Derived_By is
         Derived : TR_Vectors.Vector;
         Items   : String_Vector;
      begin
         for D of All_T loop
            if Is_Node_Type (D)
              and then D /= Root_Node_Type (Ada_Lang_Id)
              and then Base_Type (D) = T
            then
               Derived.Append (D);
            end if;
         end loop;
         for D of Derived loop
            Items.Append (Type_RST_Ref (D));
         end loop;
         if not Items.Is_Empty then
            Put_Line ("*Derived by:* " & Join (Items, ", "));
            New_Line;
         end if;
      end Emit_Derived_By;

   begin
      Emit_Header
        (Type_Display_Name (T),
         (if Is_Abstract (T) then " *(abstract)*" else ""));
      if T /= Root_Node_Type (Ada_Lang_Id) then
         Put_Line ("*Derives from:* " & Type_RST_Ref (Base_Type (T)));
         New_Line;
      end if;
      Emit_Derived_By;
      Emit_Doc_And_Members (T);
   end Emit_Node_Type;

   procedure Emit_Enum_Type (T : Type_Ref) is
      Values : constant Enum_Value_Ref_Array := All_Enum_Values (T);
      Items  : String_Vector;
   begin
      Emit_Header (Type_Display_Name (T));
      Emit_Doc (Documentation (T));
      for V of Values loop
         Items.Append (RST_Code (Name_Lower (Enum_Value_Name (V))));
      end loop;
      Put_Line ("*Values:* " & Join (Items, ", "));
      New_Line;
   end Emit_Enum_Type;

   procedure Emit_Array_Type (T : Type_Ref) is
   begin
      Emit_Header (Type_Display_Name (T));
      Put_Line ("*List of* " & Type_RST_Ref (Array_Element_Type (T)));
      New_Line;
   end Emit_Array_Type;

   procedure Emit_Struct_Type (T : Type_Ref) is
   begin
      Emit_Header (Type_Display_Name (T));
      Emit_Doc_And_Members (T);
   end Emit_Struct_Type;

   function Is_Struct_Not_Node (T : Type_Ref) return Boolean
   is (Is_Struct_Type (T) and then not Is_Node_Type (T));

   procedure Emit_Section
     (Title  : String;
      Filter : not null access function (T : Type_Ref) return Boolean;
      Emit   : not null access procedure (T : Type_Ref)) is
   begin
      Emit_Title (Title, '^');
      Vec.Clear;
      for T of All_T loop
         if Filter (T) then
            Vec.Append (T);
         end if;
      end loop;
      for T of Vec loop
         Emit (T);
      end loop;
   end Emit_Section;

begin
   for T of All_Types (Ada_Lang_Id) loop
      All_T.Append (T);
   end loop;
   TR_Sort.Sort (All_T);

   Put_Line
     ("The Libadalang API is available from LKQL rules and is the"
      & " foundation of most GNATcheck built-in rules. This section"
      & " lists all types and their members.");
   New_Line;

   Emit_Section ("``Node types``", Is_Node_Type'Access, Emit_Node_Type'Access);
   Emit_Section
     ("``Symbol types``", Is_Enum_Type'Access, Emit_Enum_Type'Access);
   Emit_Section
     ("``List types``", Is_Array_Type'Access, Emit_Array_Type'Access);
   Emit_Section
     ("``Object types``", Is_Struct_Not_Node'Access, Emit_Struct_Type'Access);

   Put_Line (".. _the origin parameter:");
   New_Line;
   Emit_Title ("The origin parameter", '^');
   Put_Line
     ("Several Libadalang properties accept an ``origin`` parameter of"
      & " type :typeref:`AdaNode`. This parameter specifies the node from"
      & " which the property is evaluated, allowing Libadalang to apply Ada"
      & " visibility rules correctly: a declaration that is visible from one"
      & " location in a program may not be visible from another. For"
      & " example, "
      & RST_Ref ("BasicDecl.p_most_visible_part")
      & " uses ``origin`` to determine which part of a declaration is"
      & " visible from the call site.");
   New_Line;
   Put_Line
     ("For more details, see the"
      & " `Libadalang user guide"
      & " <https://docs.adacore.com/live/wave/libadalang/html/"
      & "libadalang_ug/advices_gotchas.html#the-origin-parameter>`_.");
   New_Line;

end Libadalang_Api_Generator;
