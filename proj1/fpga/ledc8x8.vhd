--- Autor reseni: Lukáš Tkáč (xtkacl00@stud.fit.vutbr.cz)

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

--- ROZHRANIE OBVODU ---
entity ledc8x8 is
port ( 
    RESET : IN std_logic; --- signal pre asynchronnu inicializaciu hodnot
    SMCLK : IN std_logic; --- hodinovy signal generovaný z MCU
    ROW   : OUT std_logic_vector(0 to 7); --- signal pre vedenie riadkov maticoveho displeja
    LED   : OUT std_logic_vector(0 to 7) --- signal pre vedenie stlpcov maticoveho displeja
);
end ledc8x8;

--- DEFINICIA VNUTORNYCH SIGNALOV --- 
architecture main of ledc8x8 is

    signal ce_counter: std_logic_vector(11 downto 0) := (others => '0');
    signal freq_state: std_logic := '0';  --- signal pre ovladanie z SMCLK_divideru cinnost obvodu regulovanou ce_counterom, ktory nam spomali kmitocet hodinoveho signalu svojou bitovou dlzkou. Ktorú sme ziskali zo vztahu SMCLK/256/8
    signal sleep_state: std_logic := '0'; --- signal pre ovladanie z pause timer dekoderu a nasledne vystupu, ovladanie prechodu riadkov
    signal leds: std_logic_vector(0 to 7) := (others => '0'); --- signal pre ovladanie stlpcov displeja
    signal rows: std_logic_vector(0 to 7) := (others => '0'); --- signal pre ovladanie riadkov displeja 
    signal pause: integer range 0 to 7372800 :=0; --- pocitadlo pre pause_timer
    begin
            --- Citac pre znizovanie frekvencie SMCLK/256/8 ---
        SMCLK_divider: process(SMCLK, RESET)
            begin
                if RESET = '1' then --- ak je obvod v stave resetu vynulujem pocitadlo 
                    ce_counter <="000000000000";
                elsif (SMCLK'event and SMCLK = '1') then
                    ce_counter <= ce_counter + 1; --- pri nabeznej hrane inkrementujem pocitadlo o jedna
                    if ce_counter(11 downto 0) = "111111111111" then 
                        freq_state <= '1';
                    else
                        freq_state <= '0';
                    end if;
                end if;
            end process SMCLK_divider;
          --- FUKCIONALITA: Ocakavany pociatocny stav je 0 "ON". Potom pocitame polovicu taktu signalu t.j 3,6864 MHz(0,5 sec),
		  --- kde nasledne posleme signalu hodnotu 1 "OFF". V dekoderi nam to skoci do else vetvy, ktora je stanovena
		  --- pre hodnotu 1 "OFF" a displej sa po 0.5 sekunde svietenia vypne. Pocitame dalsiu polovicu taktu t.j do 7,3728 MHz (+ dalsej 0,5 sec),
		  --- kde nasledne asymetricky k predchadzajucemu kroku posleme signal na prebudenie, cize 0 "ON" a stav nemenime. :) 
        pause_timer: process(SMCLK, RESET)
            begin
                if RESET = '1' then 
                    pause <= 0;
                else
                if (SMCLK'event and SMCLK = '1') then
                    if (pause = 3686400) then --- + 0,5 sec SMCLK/2 = 3686400 Hz ---
                        sleep_state <= '1';
                        pause <= 3686400;
                    else
                        pause <= 1 + pause;
                    end if;
                    if (pause = 7372800) then
                            sleep_state <= '0';
                            pause <= 7372800;  --- + 0,5 sec SMCLK/2 = 7372800 Hz ---
                    else
                            pause <= 1 + pause;
                    end if;

                end if;
                end if;
            end process pause_timer;
                    


        --- proces pre rotovanie riadkov maticovym displejom ---
        rotate_row: process(SMCLK, RESET, freq_state, rows)
        begin
            if RESET = '1' then
            rows <= "10000000"; 
            elsif (SMCLK'event and SMCLK = '1' and freq_state = '1') then
                    rows <= rows(7) & rows(0 to 6); --- rotovanie riadkami za pomoci konkatenacie  
                end if;
            ROW <= rows;
        end process rotate_row;
              
    decoder: process(rows, sleep_state)
        begin
            if sleep_state = '0' then
                case rows is
                    when "10000000" | "01000000" => leds <= "00110000"; 
                    when "00100000" | "00010000" | "00001000" | "00000100" => leds <= "00111001";
                    when "00000010" | "00000001" => leds <= "00001001";
                    when others => leds <= (others => '1');
                end case;
            else
            case rows is
                when "10000000" | "01000000" | "00100000" | "00010000" | "00001000" | "00000100" | "00000010" | "00000001" => leds <= (others => '1');
                when others => leds <= (others => '1');
            end case;
            end if;       
        end process decoder;

        ROW <= rows; 
        LED <= leds;
end main;


