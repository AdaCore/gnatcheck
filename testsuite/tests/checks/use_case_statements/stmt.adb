procedure Stmt is
   type Enum is (OK, Partial, KO);
   Result, Result2 : Enum;

   procedure Proc (I, L, R : in out Integer) is
   begin
      if I < 1 then    --  NOFLAG
         I := I + 1;
      elsif I in L .. R then
         I := I - 1;
      else
         I := 0;
      end if;
   end Proc;

   type Rec is record
      Field : Integer;
   end record;

   function Func1 (Item : Rec) return String is
   begin
      if Item.Field < 0 then  --  FLAG
         return "aa";
      elsif Item.Field = 0 then
         return "bb";
      else
         return "cc";
      end if;
   end Func1;

begin
   if Result = OK then   --  FLAG
      null;
   elsif Result = Partial then
      null;
   elsif Result = KO then
      null;
   end if;

   if Result = OK then   --  NOFLAG
      null;
   else
      null;
   end if;

   if Result = OK then   --  NOFLAG
      null;
   elsif Result2 = OK then
      null;
   else
      null;
   end if;

   declare
      function ">" (L, R : Integer) return Boolean is (L + R <= L - R);
      I : Integer;
   begin
      if I = 1 then      --  NOFLAG
         I := I + 1;
      elsif I > 20 then
         I := I + 2;
      else
         I := 0;
      end if;
   end;

   declare
      F : Float;
      I : Integer;
   begin
      if F >= 1.0 then   --  NOFLAG
         I := I + 1;
      elsif F <= 0.0 then
         I := I - 1;
      else
         I := 0;
      end if;
   end;

   declare
      subtype Even is Integer with Dynamic_Predicate => Even mod 2 = 0;
      I, K : Integer;

      function F return Integer is (I);
   begin
      if I = 1 or I = 2 then    --  FLAG
         I := 0;
      elsif I = 3 then
         I := 1;
      else
         I := 2;
      end if;

      if I in 1 .. 5 then       --  FLAG
         I := 0;
      elsif I = 6 or I = 7 then
         I := 1;
      else
         I := 2;
      end if;

      if I >= 1 and I <= 5 then --  FLAG
         I := 0;
      elsif I = 6 then
         I := 1;
      end if;

      if (I >= 1) and (I <= 5) then  --  FLAG
         I := 0;
      elsif I = 6 then
         I := 1;
      end if;

      if I = 1 or I in 8 .. 10 then  --  FLAG
         I := 0;
      elsif I = 6 then
         I := 1;
      end if;

      if I = 1 or K = 2 then    --  NOFLAG (different variable)
         I := 0;
      elsif I = 3 then
         I := 1;
      end if;

      if I = 1 or else I = 2 then           --  FLAG
         I := 0;
      elsif I >= 3 and then I <= 5 then
         if K = 1 then                      --  FLAG
            K := 0;
         elsif K = 2 then
            K := 1;
         end if;
      end if;

      if I in Even then                     --  NOFLAG (non-static subtype)
         I := 0;
      elsif I = 5 then
         I := 1;
      end if;

      if I in Natural then                  --  FLAG
         I := 0;
      elsif I = -1 then
         I := 1;
      end if;

      if F = 1 then                         --  NOFLAG (function call)
         I := 0;
      elsif F = 2 then
         I := 1;
      end if;

      if I = 1 then                         --  NOFLAG (not a name)
         I := 0;
      elsif I + 1 in 2 .. 3 then
         I := 1;
      end if;
   end;

   declare
      function Get_Record return Rec is ((Field => 1));
   begin
      if Get_Record.Field = 1 or Get_Record.Field = 2 then --  NOFLAG
         null;
      elsif Get_Record.Field = 3 then
         null;
      end if;
   end;

   declare
      package My_Pkg is
         My_Obj : Integer := 3;
      end My_Pkg;
   begin
      if My_Pkg.My_Obj = 3 or My_Pkg.My_Obj = 4 then --  FLAG
         null;
      elsif My_Pkg.My_Obj = 5 then
         null;
      end if;
   end;
end Stmt;
