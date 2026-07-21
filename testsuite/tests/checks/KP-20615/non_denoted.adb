with Pkg; use Pkg;

procedure Non_Denoted is

   --  A body-only override of an inherited primitive that is NOT denoted by
   --  the inherited Aggregate aspect (here Clear) is harmless: not flagged.
   type Local_Set is new Set;

   procedure Clear (S : in out Local_Set) is  -- NOFLAG
   begin
      null;
   end Clear;

   L : Local_Set := [1, 2];

begin
   Clear (L);
end Non_Denoted;
