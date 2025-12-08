library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity demux_1to2 is
 port(

 F : in std_logic_vector(31 downto 0);
 S: in STD_LOGIC;
 A,B: out std_logic_vector(31 downto 0);
 );
end demux_1to4;

architecture bhv of demux_1to4 is
begin
process (F,S0,S1) is
begin
 if (S ='0') then
 A <= F;
 elsif (S0 ='1) then
 B <= F;
 end if;

end process;
end bhv;