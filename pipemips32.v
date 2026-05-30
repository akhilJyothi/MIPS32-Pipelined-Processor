module pipemips32 (clk1,clk2);
input clk1,clk2;
reg [31:0] IF_ID_IR, IF_ID_NPC, PC;                                     //if stage registers
reg [31:0] ID_EX_IR, ID_EX_IMM, ID_EX_B, ID_EX_A, ID_EX_NPC;      //id stage registers
reg [31:0] EX_MEM_IR,EX_MEM_B, EX_MEM_ALUOUT;
reg EX_MEM_COND;
reg[2:0] ID_EX_TYPE, EX_MEM_TYPE, MEM_WB_TYPE;
reg [31:0] MEM_WB_IR, MEM_WB_ALUOUT,MEM_WB_LMD;

reg[31:0] regbank[31:0]; //32 register - Temp working variables
reg [31:0] mem [0:1023]; //1024 locations- Store prgm+data
parameter ADD = 6'b000000, SUB = 6'b000001, AND=6'b000010, OR= 6'b000011, SLT= 6'b000100, 
 MUL= 6'b000101 ; HLT = 6'b000110, LD = 6'b001000, STR = 6'b001001, ADDI = 6'b001010,
 SUBI = 6'b001011, SLTI = 6'b001100, BNEQZ = 6'b001101, BEQZ = 6'b001110;
// SLT: set_if_less_than
 
 parameter 
 RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE= 3'b011, BR= 3'b100, HALT= 3'b101 ;
reg HALTED;
reg TAKENBRANCH;

 //IF stage
always @(posedge clk1)
 begin
  if (HALTED==0)
begin
    if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_COND==1)) ||
    ((EX_MEM_IR[31:26]==BNEQZ)&& (EX_MEM_COND==0)))
    begin
    IF_ID_IR <= mem[EX_MEM_ALUOUT];
    TAKENBRANCH<=1'B1;
    IF_ID_NPC <= mem[EX_MEM_ALUOUT+1];
    PC<=mem[EX_MEM_ALUOUT+1];
    else
        IF_ID_IR<= mem[PC];
        PC<=PC+1;
        IF_ID_NPC<=PC+1;
    end 
end      
end

//ID stage
always @(posedge clk2)
if (HALTED==0)
    begin
    if (IF_ID_IR[25:21]==5'b00000) // checking if rs=R0, 
     ID_EX_A<=0;                   //R0 is specified in arch to contain only zero
    else   // mannually giving zero because maybe initially , R0 was not zero
    ID_EX_A<= regbank[IF_ID_IR[25:21]];   // and so if R0 was not zero, it could contain rubbish
    if (IF_ID_IR[20:16]==5'b00000)     // so mannually assigning value of zero.
    ID_EX_B<=0;
    else
        ID_EX_B<= regbank[IF_ID_IR[20:16]];
    ID_EX_NPC<= IF_ID_NPC;
    ID_EX_IR<= IF_ID_IR;
    ID_EX_IMM<= {{16{IF_ID_IR[15]}},IF_ID_IR[15:0]};
   
    case(IF_ID_IR[31:26])
    ADD,SUB,AND,OR,MUL,SLT : ID_EX_TYPE <= RR_ALU  /////DEFINE TYPES
    ADDI, SUBI,SLTI : ID_EX_TYPE <=RM_ALU;
    LD: ID_EX_TYPE <=LOAD;
    STR: ID_EX_TYPE <=STORE;
    HLT: ID_EX_TYPE <=HALT;
    BNEQZ, BEQZ:ID_EX_TYPE <= BR;
    default:  ID_EX_TYPE <= HALT;
    endcase

end

//EX Stage
always @(posedge clk1) 
begin
    if (HALTED==0)
    begin
        EX_MEM_TYPE<=ID_EX_TYPE;
        EX_MEM_IR<= ID_EX_IR;
        TAKENBRANCH<= 0;    ////// variable was set in the if stage???
       // EX_MEM_A<=ID_EX_A;      // Wrong pipeline as we' be storing      
      // EX_MEM_B<=ID_EX_B;          results from here in EX_MEM stage
        case (ID_EX_TYPE)
          RR_ALU: 
          begin
            case (ID_EX_IR[31:26])
              ADD:  EX_MEM_ALUOUT<= ID_EX_A + ID_EX_B;
              SUB:  EX_MEM_ALUOUT <= ID_EX_A- ID_EX_B;
              AND:  EX_MEM_ALUOUT <= ID_EX_A & ID_EX_B;
              OR:   EX_MEM_ALUOUT <= ID_EX_A | ID_EX_B;
              MUL:  EX_MEM_ALUOUT <= ID_EX_A * ID_EX_B;
              SLT:  EX_MEM_ALUOUT <= ID_EX_A <ID_EX_B;   // this is a conditional statement 
            default:EX_MEM_ALUOUT<= 32'hxxxxxxxx    ;     //that returns true or false
            endcase
          end

          RM_ALU:
          case (ID_EX_IR[31:26])
            ADDI: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;  // immediate
            SUBI: EX_MEM_ALUOUT <= ID_EX_A - ID_EX_IMM;
            SLTI: EX_MEM_ALUOUT <= ID_EX_A <ID_EX_IMM;
            default:  EX_MEM_ALUOUT<= 32'hxxxxxxxx; 
          endcase
            
          LOAD,STORE:
          begin
            EX_MEM_ALUOUT <= ID_EX_A+ ID_EX_IMM;  // address calculation    
            EX_MEM_B<=ID_EX_B;
          end
           
         BR:
         begin
            EX_MEM_ALUOUT<=ID_EX_NPC+ID_EX_IMM;
            EX_MEM_COND<= (ID_EX_A==0);
         end
        endcase
    end
    
end
// case (ID_EX_IR[31:26])  // check opcode
//     ADD:  EX_MEM_ALUOUT <= ID_EX_A + ID_EX_B;
//     SUB:  EX_MEM_ALUOUT <= ID_EX_A - ID_EX_B;
//     AND:  EX_MEM_ALUOUT <= ID_EX_A & ID_EX_B;
//     OR:   EX_MEM_ALUOUT <= ID_EX_A | ID_EX_B;
//     MUL:  EX_MEM_ALUOUT <= ID_EX_A * ID_EX_B;
    
//     ADDI: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;  // immediate
    
//     LD:   EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;  // address calculation
//     STR:  EX_MEM_ALUOUT <= ID_EX_A + ID_EX_IMM;  // address calculation

//     HALT: HALTED <= 1'b1;

//     default: ;  // do nothing for unrecognized opcodes
// endcase

//MEM stage
always @(posedge clk2) 
if(HALTED==0)
begin
    MEM_WB_IR<= EX_MEM_IR;
    MEM_WB_TYPE<= EX_MEM_TYPE;
    case (EX_MEM_TYPE)
       RR_ALU : MEM_WB_ALUOUT<= EX_MEM_ALUOUT;
       RM_ALU:  MEM_WB_ALUOUT<= EX_MEM_ALUOUT;
       LOAD :   MEM_WB_LMD<= mem[EX_MEM_ALUOUT] ;
       STORE: if(TAKENBRANCH==0)          // disable write if branch is taken
                     mem[EX_MEM_ALUOUT]<= EX_MEM_B;
    endcase
end

//WB stage
//WB: result is finally written into register file,the destination to which the
// result is to be stored will be avaialable in the rt feild[15:10] in opcode
always @(posedge clk1) 
begin
    if (TAKENBRANCH==0)  //disable write if branch is taken
    begin
    case (MEM_WB_TYPE)
       RR_ALU : regbank[MEM_WB_IR[15:11]]<= MEM_WB_ALUOUT ; //rd:destination reg in opcode
       RM_ALU : regbank[MEM_WB_IR[20:16]]<= MEM_WB_ALUOUT; //rt: rt=destination for I type
       LOAD: regbank[MEM_WB_IR[20:16]]<= MEM_WB_LMD;
       HALT : HALTED<= 1'b1;
    endcase    
    end
    
end

endmodule