function Main return access String is
   B       : Boolean := True;
   Outer_S : access String := null;

   type Str_Rec is record
      S : access String;
   end record;

   type Str_Rec_Rec is record
      R : Str_Rec;
   end record;

   function Fn_Str_Acc return access String is
   begin
      return new String'("hello");  -- NOFLAG
   end Fn_Str_Acc;

   function Fn_If_Str_Acc return access String is
      S_1 : access String;
      S_2 : access String;
      S_3 : access String;
   begin
      if B then
         S_1 := new String'("hello");      -- FLAG (Over approximation of the detector)

      elsif B then
         Outer_S := new String'("hello");  -- NOFLAG (Outer_S isn't return in this function)

      elsif B then
         S_2 := new String'("hello");      -- FLAG (S_2 is assigned to S_1)

         --  Ensure the rule is handling assignment cycles
         S_1 := S_2;
         S_2 := S_1;

      elsif B then
         S_3 := new String'("hello");      -- NOFLAG (This is not returned in a conditional construct)

      elsif B then
         S_1 := new String'("hello");      -- FLAG (S_1 is immediately returned)
         return S_1;

      elsif B then
         return S : access String do
            S := new String'("hello");     -- FLAG
         end return;

      elsif B then
         declare
            Inner_S : access String := new String'("hello");  -- FLAG
         begin
            return Inner_S;
         end;

      elsif B then
         declare
            Inner_S : access String := new String'("hello");  -- FLAG
            Renamed_S : access String renames Inner_S;
         begin
            return Renamed_S;
         end;

      else
         return new String'("hello");      -- FLAG
      end if;

      if B then
         declare
            function Inner_Fn return access String is
            begin
               return new String'("hello");  -- NOFLAG (Conditional statement is outside the function)
            end Inner_Fn;
         begin
            null;
         end;
      end if;

      return S_3;
   end Fn_If_Str_Acc;

   function Fn_If_Expr_Str_Acc return access String is
   begin
      return (if B then new String'("hello") else null);  -- FLAG
   end Fn_If_Expr_Str_Acc;

   function Fn_Case_Str_Acc return access String is
      S_1 : access String;
      S_2 : access String;
   begin
      case B is
         when True   =>
            S_1 := new String'("hello");    -- FLAG (Over approximation of the detector)

         when False  =>
            S_2 := new String'("hello");    -- NOFLAG (S_2 is always returned at the end of the function)

         when others =>
            S_1 := new String'("hello");    -- FLAG (S_1 is immediately returned)
            return S_1;
      end case;

      return S_2;
   end Fn_Case_Str_Acc;

   function Fn_Case_Expr_Str_Acc return access String is
   begin
      return
        (case B is
           when True   => new String'("hello"),  -- FLAG
           when others => null);
   end Fn_Case_Expr_Str_Acc;

   function Fn_Goto_Str_Acc return access String is
   begin
      goto lbl;
      <<lbl>>
      return new String'("hello");  -- FLAG (always flag when function body has a "goto" statement)
   end Fn_Goto_Str_Acc;

   function Fn_Inner_Goto_Str_Acc return access String is
      procedure Inner is
      begin
         goto lbl;
         <<lbl>>
      end Inner;
   begin
      declare
         procedure Inner is
         begin
            goto lbl;
            <<lbl>>
         end Inner;
      begin
         null;
      end;
      return new String'("hello");  -- NOFLAG (Goto statements are in inner functions)
   end Fn_Inner_Goto_Str_Acc;

   function Fn_Exit_When_Str_Acc return access String is
      S : access String;
   begin
      S := new String'("hello");  -- FLAG (always flag when function body has a "exit when" statement)
      loop
         exit when B;
         B := True;
         return S;
      end loop;
      return null;
   end Fn_Exit_When_Str_Acc;

   function Expr_Fn_If_Str_Acc return access String
   is (if B then new String'("hello") else null);  -- FLAG

   function Fn_If_Str_Rec return Str_Rec is
      R     : Str_Rec;
      Tmp_R : Str_Rec;
   begin
      if B then
         Tmp_R.S := new String'("hello");     -- NOFLAG

      end if;

      if B then
         return (S => new String'("hello"));  -- FLAG

      else
         R.S := new String'("hello");         -- FLAG
         return R;
      end if;
   end Fn_If_Str_Rec;

   function Fn_If_Str_Rec_Rec return Str_Rec_Rec is
      R       : Str_Rec;
      R_R     : Str_Rec_Rec;
      Tmp_R_R : Str_Rec_Rec;
   begin
      if B then
         Tmp_R_R.R := (S => new String'("hello"));   -- NOFLAG

      end if;

      if B then
         return (R => (S => new String'("hello")));  -- FLAG

      else
         R.S := new String'("hello");                -- FLAG
         R_R.R := R;
         return R_R;
      end if;
   end Fn_If_Str_Rec_Rec;
begin
   if B then
      return Outer_S;
   end if;
end Main;
