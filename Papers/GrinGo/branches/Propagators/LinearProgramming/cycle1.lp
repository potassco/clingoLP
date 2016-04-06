compound("M_A_c","C_c","false").
compound("M_B_c","C_c","false").
compound("M_C_c","C_c","false").
compound("M_D_c","C_c","false").
compound("M_E_c","C_c","false").
compound("M_F_c","C_c","false").
compound("M_A_b","C_b","true").

compartment("C_c").
compartment("C_b").

reaction("R_boundaryA",0,"draft").
reactant("M_A_b",1,"R_boundaryA","draft").
product("M_A_c","1","R_boundaryA","draft").
bounds("R_boundaryA","0","99999").

reaction("R_R1",0,"draft").
reactant("M_B_c",1,"R_R1","draft").
product("M_C_c","2","R_R1","draft").
bounds("R_R1","0","99999").

reaction("R_R2",0,"draft").
reactant("M_C_c",1,"R_R2","draft").
product("M_D_c","1","R_R2","draft").
bounds("R_R2","0","99999").

reaction("R_R3",0,"draft").
reactant("M_A_c",1,"R_R3","draft").
reactant("M_D_c",1,"R_R3","draft").
product("M_B_c","1","R_R3","draft").
bounds("R_R3","0","99999").

reaction("R_R4",0,"draft").
reactant("M_C_c",1,"R_R4","draft").
product("M_E_c","1","R_R4","draft").
bounds("R_R4","0","99999").

reaction("R_R4_2",0,"draft").
product("M_C_c","1","R_R4_2","draft").
reactant("M_E_c",1,"R_R4_2","draft").
bounds("R_R4_2","0","99999").

reaction("R_R5",0,"draft").
reactant("M_E_c",1,"R_R5","draft").
product("M_F_c","1","R_R5","draft").
bounds("R_R5","0","99999").

reaction("R_biomass",1,"draft").
reactant("M_F_c",1,"R_biomass","draft").
bounds("R_biomass","0","99999").
