#!/usr/bin/python

import sys, getopt
import xml.etree.ElementTree as eltr

boundary_cond = {} # {id : bool}
lb = 0
ub = 0
obj = 0

def main(argv):
    inputfiles = []
    outputfiles = []
    lp_type = ""
    try:
        opts, args = getopt.getopt(argv,"hi:o:",["ifile=","ofile="])
    except getopt.GetoptError:
        print('flux-converter.py -i <inputfiles> -o <outputfile>')
        sys.exit(2)
    if opts == []:       
        print('flux-converter.py -i <inputfiles> -o <outputfile>')
        sys.exit()
    for opt, arg in opts:
        if opt == '-h':
            print('flux-converter.py -i <inputfiles> -o <outputfile>')
            sys.exit()
        elif opt in ("-i", "--ifile"):
            inputfiles.append(arg)
        elif opt in ("-o", "--ofile"):
            outputfiles.append(arg)
    outputfile = outputfiles[0]
    if "seeds" in outputfile:
        lp_type = "s_"
    elif "targets" in outputfile:
        lp_type = "t_"
    elif "degraded" in outputfile or "draft" in outputfile:
        lp_type = "d_"
    elif "reconstructed" in outputfile or "repair" in outputfile or "bdd" in outputfile:
        lp_type = "r_"
    else: 
        lp_type = "lp_"
    outdata=open(outputfile,'w')
    for inputfile in inputfiles:
        intree = eltr.parse(inputfile)
        inroot = intree.getroot()
        for e in inroot.iter():
            #if 'compartment' == e.tag.split('}')[1]: # compartment
            #    #print('compartment')
            #    #print(e.attrib)  
            #    compartment = lp_type+'compartment("'+e.attrib['id']+'").\n'
            #    outdata.write(compartment)
            #elif 'species' == e.tag.split('}')[1]: # compound
            if 'species' == e.tag.split('}')[1]: # compound
                #print('species')
                #print(e.attrib)  
                compound = lp_type+'compound("'+e.attrib['id']+'","'+e.attrib['compartment']+'","'+e.attrib['boundaryCondition']+'").\n'
                outdata.write(compound)
            elif 'reaction' == e.tag.split('}')[1]: # reaction
                if e.getchildren() != []:
                    #print('reaction')
                    #print(e.attrib)
                    reaction = lp_type+'reaction("'+e.attrib['id']+'").\n'
                    outdata.write(reaction)
                    if e.attrib['reversible'] == 'true':
                        revers_react = 'reversible("'+e.attrib['id']+'").\n'
                        outdata.write(revers_react)
                    for ee in e.getchildren():
                        if 'listOfReactants' == ee.tag.split('}')[1]:  
                            for eee in ee.getchildren(): # reactant
                                #print(eee.attrib) 
                                reactant = lp_type+'reactant("'+eee.attrib['species']+'","'+eee.attrib['stoichiometry']+'","'+e.attrib['id']+'").\n'
                                outdata.write(reactant) 
                        elif 'listOfProducts' == ee.tag.split('}')[1]:
                            #print('Products')
                            for eee in ee.getchildren(): # product
                                #print(eee.attrib)
                                product = lp_type+'product("'+eee.attrib['species']+'","'+eee.attrib['stoichiometry']+'","'+e.attrib['id']+'").\n'
                                outdata.write(product)
                        elif 'kineticLaw' == ee.tag.split('}')[1]:
                            for eee in ee.getchildren():
                                if 'listOfParameters' == eee.tag.split('}')[1]:
                                    #print('Parameter')
                                    for eeee in eee.getchildren(): # bounds and objective
                                        #print(eeee.attrib)
                                        if eeee.attrib['id'] == 'LOWER_BOUND':
                                            lb = eeee.attrib['value']
                                        elif eeee.attrib['id'] == 'UPPER_BOUND':
                                            ub = eeee.attrib['value']
                                        elif eeee.attrib['id'] == 'OBJECTIVE_COEFFICIENT': 
                                            obj = eeee.attrib['value']
                                    bounds = lp_type+'bounds("'+e.attrib['id']+'","'+lb+'","'+ub+'").\n'
                                    outdata.write(bounds)
                                    objective = lp_type+'objective("'+e.attrib['id']+'","'+obj+'").\n'
                                    outdata.write(objective)
        print('flux-converter parsed xml-fomat '+inputfile+' into asp-format '+outputfile)
    outdata.close()

if __name__ == "__main__":
    main(sys.argv[1:])
