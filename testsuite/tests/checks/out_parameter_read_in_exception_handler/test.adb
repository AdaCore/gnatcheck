with Ada.Text_IO; use Ada.Text_IO;

procedure Test is
   procedure Change (X : out Integer) is
   begin
      X := 1;
      raise Program_Error;
   end Change;

   procedure Change (X : in Float) is null;

   procedure Change (X : in out Boolean) is null;

   procedure Change2 (X : out Integer; Y : out Integer) is null;

   I, J, K, L : Integer := 0;
   F          : Float := 0.0;
   B          : Boolean := True;
   M, N, P    : Integer := 0;
   R          : Integer renames L;
begin
   --  Basic cases

   begin
      Change (I);       --  FLAG
      Change (Test.K);  --  FLAG
      Change (J);       --  NOFLAG: J is not read in any exception handler
      Change (F);       --  NOFLAG: in mode parameter
      Change (B);       --  FLAG
      Change (B'Pos);   --  NOFLAG: not an Identifier or DottedName
   exception
      when Program_Error =>
         Put_Line (Integer'Image (I));
         Put_Line (Integer'Image (K));
      when others =>
         Put_Line (B'Image);
   end;

   --  Call inside an exception handler: filtered out regardless of reads

   begin
      null;
   exception
      when Program_Error =>
         Change (I);  --  NOFLAG: ParamAssoc is inside an ExceptionHandler
   end;

   --  Multiple out parameters: only the one read in the handler is flagged

   begin
      Change2 (M, N);  --  FLAG for M, NOFLAG for N: N is not read in handler
   exception
      when others =>
         Put_Line (Integer'Image (M));  --  M is read, N is not
   end;

   --  Call in a nested inner block, variable read in the outer handler:
   --  the call is not directly in the outer HandledStmts.f_stmts, flag anyway.

   begin
      begin
         Change (P);  --  FLAG: call is nested inside an inner block
      end;
   exception
      when others =>
         Put_Line (Integer'Image (P));
   end;

   --  Renamed variable read in handler (R renames L)

   begin
      Change (L);  --  FLAG
   exception
      when others =>
         Put_Line (Integer'Image (R));
   end;

   begin
      Change (R);  --  FLAG
   exception
      when others =>
         Put_Line (Integer'Image (L));
   end;

   begin
      Change (R);  --  FLAG
   exception
      when others =>
         Put_Line (Integer'Image (R));
   end;

end Test;
