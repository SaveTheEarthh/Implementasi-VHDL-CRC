library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity demux_1to2 is
 port(

 F : in std_logic_vector(31 downto 0);
 S: in STD_LOGIC;
 A,B: out std_logic_vector(31 downto 0)
 );
end demux_1to2;

architecture bhv of demux_1to2 is
begin
process (F,S) is
begin
 if (S ='0') then
 B <= F;
 elsif (S ='1') then
 A <= F;
 end if;

end process;
end bhv;