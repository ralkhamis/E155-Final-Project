// E155 final project
// Reem Alkhamis & Sabrine Griffith
module finalProjectTest(input logic clk,
        input logic reset,               // active low reset
        input logic mosi,                // slave input 
        input logic sclk,                // serial clock 
		  input logic we, spiready,        // write enable and chip enable 

         output logic [2:0] RGB1, RGB2, // to the matrix
         output logic BLANK,            // OE: output enable (blanking singal, erases the board)
         output logic LAT,             // LAT: takes data from shift reg to the output register
         output logic [3:0] row,
         output logic matrixclk);
        
 logic [3:0] slowClk1;
 
 always_ff@(posedge clk, negedge reset)
  if (!reset) slowClk1 <=0;
  else
	slowClk1 <= slowClk1 + 1'b1;
  

 
 slowClkProject project(clk, slowClk1[3], reset, we, spiready, mosi, sclk, RGB1, RGB2, BLANK, LAT, row, matrixclk);
 
endmodule


module slowClkProject(input logic fastClk,
							input logic clk,
							 input logic reset, 
							 input logic we, spiready,
							input logic mosi,
						   input logic sclk,
							output logic [2:0] RGB1, RGB2, 
							output logic BLANK,  
							output logic LAT, 
							output logic [3:0] row,
							output logic matrixclk);
      
     
 

// pin assignments 
// RGB1[2:0]: (RED) R1=RGB1[2], (GREEN) G1=RGB1[1], (BLUE) B1=RBG1[0]
// Rows 31:16
// RGB2[2:0]: (RED) R2=RGB2[2], (GREEN) G2=RGB2[1], (BLUE) B1=2=RBG2[0]
// row[3:0]: D = row[3], C=row[2], B=row[1], A=row[0]
// LAT   -> PIN_42 
// OE    -> PIN_43 
// D     -> PIN_38
// C     -> PIN_34
// B     -> PIN_33
// A     -> PIN_32 
// reset -> PIN_1
// R1    -> PIN_7
// B1    -> PIN_11
// G1    -> PIN_10 // changed to PIN_3
// R2    -> PIN_28
// B2    -> PIN_31
// G2    -> PIN_30
// MarixClk -> PIN_39 
//////////////////////////////////////////////////
 logic [5:0] counter;
 logic [95:0] row0, row1;
 logic [95:0] spidata;
 logic [4:0] col;
 logic [3:0] radr;
 logic [4:0] wadr;
 logic hold;

 
	 always_ff@(posedge clk, negedge reset)
		  if (!reset)  begin
			counter<=0;
			col<=0;
			hold <=1;
		end
		  else if (counter == 60 || hold==1)
			begin
			col <= 0;
			counter <=0;
			hold<=0;
		  end
		 else if (counter>=31 && counter<60) begin
		  col <=col;
		  counter <= counter+ 1'b1;
		 end
		 
		  else if (hold==0) begin
		  counter <= counter + 1'b1;
		  col <= col+1'b1;
		  
		 end
	 
	 
 //////////
	 always_ff@(posedge clk, negedge reset)
		if (!reset)  begin
			row<=0;
	 end 
		else begin
		  if (counter==60 ) 
				row <= row + 1'b1;  
	  end
  

  controller controller(clk, reset, counter, BLANK, LAT);
  memRead memRead(clk, reset, LAT, BLANK, radr);
  // We are using two RAMs in order to display two rows simultaneously.
  dmemtop dmemt(fastClk, reset, we, wadr, radr, spidata,  row0);
  dmembottom dmemb(fastClk, reset, we, wadr, radr, spidata,  row1);
  
  driveColor color(matrixclk, row0, row1, col, RGB1, RGB2);
  spi spi(fastClk, sclk, reset, we, spiready, mosi, wadr, spidata);
 
 
  
  
	always_comb
		 if (counter <32)
				matrixclk = clk;
		 else if (counter==60)
				matrixclk=0;
		 else
				matrixclk =1;
       
endmodule

module controller(input logic clk, reset, // 2.5MHz
					  input logic [5:0] counter,
					  output logic BLANK,  
					  output logic LAT); 
					  
 
 always_ff@(posedge clk)
		 begin
		 
		  if (counter==32) begin
			 LAT <= 1;
			 BLANK<=1; end 
			else if (counter==33) begin
			 LAT <= 0; 
			 BLANK<=0;
			 end
		  else if (counter>=34 && counter <=59) begin
			 LAT <= 0; 
			 BLANK<=0; 
			 end

		  else begin
			BLANK <= 1;
			LAT <=0; end
			end

endmodule 
 

module driveColor(input logic matrixclk, 
						input logic [95:0] row0, row1, // read data from RAM
						input logic [4:0] col,
						output logic [2:0] RGB1, RGB2);
		
	always_ff@(negedge matrixclk) begin
		 RGB1[0] <= row0[3*col];
		 RGB1[1] <= row0[3*col+1];
		 RGB1[2] <= row0[3*col+2];
		 
		 RGB2[0] <= row1[3*col];
		 RGB2[1] <= row1[3*col+1];
		 RGB2[2] <= row1[3*col+2];
		 end
		

    
endmodule
/// we are sending through spi 108 bits every time
// 96 bits of data, 5 bits of address and 7 unused bit
// initilizing memory with the static image in a text file
	

module memRead(input logic clk,
					input logic reset,
					input logic LAT,
					input logic BLANK,
					output logic [3:0] radr); 	
	
		always_ff@(posedge clk, negedge reset) begin // 2.5MHz clk
			if (!reset)  
				radr<=0;
			 
			else if (LAT && BLANK) 
				radr <= radr+1;
			

				
				end				
					
endmodule 


module spi(input logic fastclk, sclk, reset, 
			  input logic we, spiready,
			  input logic mosi,
			  output logic [4:0] wadr,
			  output logic [95:0] spidata);
	
	logic [107:0] q;

			always_ff@(posedge sclk, negedge reset) begin
				if (!reset) q <=0; 
				else if (spiready)
					 q <= {q[106:0], mosi};
			end		 
			
			always_ff@(posedge fastclk) begin  // writing on the 40MHz clk
				if (we) begin
					wadr<= q[100:96]; // unused 7 bits
					spidata <= q[95:0];
					end
			end
					 	  			  
endmodule 			  		  



module dmemtop(input logic fastclk, reset, // 40MHz clk
				input logic we,			// write enable
				input logic [4:0] wadr, // write address 
				input logic [3:0] radr, // read address 
				input logic [95:0] row_data, // write data 
				output logic [95:0] row0); // read data

	
	logic [95:0] RAM[31:0];	
	initial 
		$readmemb("heart.dat",RAM); 
	
		always_ff@(posedge fastclk) 
			row0 <= RAM[radr];
	
		

		always_ff@(posedge fastclk) 
			if (we) 
				RAM[wadr] <= row_data;
	
endmodule 

module dmembottom(input logic fastclk, reset, // 40MHz clk
				input logic we,			// write enable
				input logic [4:0] wadr, // write address 
				input logic [3:0] radr, // read address 
				input logic [95:0] row_data, // write data 
				output logic [95:0]row1); // read data

	
	logic [95:0] RAM[31:0];	
	initial 
		$readmemb("heart.dat",RAM); 
	
		always_ff@(posedge fastclk) 
			row1 <= RAM[radr+16];
	
		

		always_ff@(posedge fastclk) 
			if (we) 
				RAM[wadr] <= row_data;
	
endmodule 