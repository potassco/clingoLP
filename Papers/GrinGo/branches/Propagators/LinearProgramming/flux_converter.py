#!/usr/bin/python

import sys
# import re
import xml.etree.ElementTree as etree
from xml.etree.ElementTree import XML, fromstring, tostring
from pyasp.asp import *
import argparse



# boundary_cond = {} # {id : bool}
# lb = 0
# ub = 0
# obj = 0

def main(all_args):

    draft_sbml   = all_args.draftnet
    repair_sbml  = all_args.repairnet
    output_file  = all_args.output

    draftnet, seeds, targets = readSBMLnetwork(draft_sbml, 'd')
    repairnet = readSBMLnetwork(repair_sbml, 'r')[0]

    draftnet.to_file(output_file + '_draft.lp')
    repairnet.to_file(output_file + '_repair.lp')
    #print(repairnet)

    return

def get_model(sbml):
    """ get the model of a SBML file"""
    model_element = None
    for e in sbml:
        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "model":
            model_element = e
            break
    return model_element

def get_listOfSpecies(model):
    """ get list of species (compounds) for a model in a SBML file """
    listOfSpecies = None
    for e in model:
        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "listOfSpecies":
            listOfSpecies = e
            break
    return listOfSpecies

def get_listOfReactions(model):
    """ get list of reactions for a model in a SBML file """
    listOfReactions = None
    for e in model:
        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "listOfReactions":
            listOfReactions = e
            break
    return(listOfReactions)

def get_listOfReactants(reaction):
    """ get list of reactants for a reaction in a SBML file """
    listOfReactants = None
    for e in reaction:
        if e.tag[0] == "{":
          uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "listOfReactants":
            listOfReactants = e
            break
    return listOfReactants

def get_listOfProducts(reaction):
    """ get list of products for a reaction in a SBML file """
    listOfProducts = None
    for e in reaction:
        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "listOfProducts":
            listOfProducts = e
            break
    return listOfProducts


def get_listOfParameters(reaction):
    """ get list of parameters for a reaction in a SBML file """
    listOfParameters = None
    for e in reaction:
        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        #print(tag)
        if tag == "kineticLaw":
            kineticLaw = e
            #print(kineticLaw)
            for ee in kineticLaw:
                if ee.tag[0] == "{":
                    uri, tag = ee.tag[1:].split("}")
                else:
                    tag = ee.tag
                #print(tag)
                if tag == "listOfParameters":
                    listOfParameters = ee
                    break
    return listOfParameters


def readSBMLnetwork(filename, prefix) :
    """ create lp facts for the network from SBML """

    lpfacts         = TermSet()
    tree            = etree.parse(filename)
    sbml            = tree.getroot()
    model           = get_model(sbml)
    listOfReactions = get_listOfReactions(model)
    listOfSpecies   = get_listOfSpecies(model)

    seeds = []
    targets = []
    objective_reactions = []
    species_data = {}
    added_species = []

    # lpfacts.add(Term(name,["\""+name+"\""])

    # get list of species
    for e in listOfSpecies:
        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "species":
            speciesId = e.attrib.get("id")
            speciesBC = e.attrib.get("boundaryCondition")
            speciesCp = e.attrib.get("compartment")
            # only add seeds if the BC true compound is in the draft, not the repair database
            if speciesBC == "true" and prefix == 'd':
                seeds.append(speciesId)
                lpfacts.add(Term('s_compound', ["\""+speciesId+"\"", "\""+speciesCp+"\"", "\""+speciesBC+"\""]))
                if not speciesId in species_data:
                    species_data[speciesId] = {'compartment':speciesCp, 'boundaryCondition':speciesBC}
                else:
                    print('Error: compound ' + speciesId + 'is defined twice')
                    quit()
            else:
                if not speciesId in species_data:
                    species_data[speciesId] = {'compartment':speciesCp, 'boundaryCondition':speciesBC}
                else:
                    print('Error: compound ' + speciesId + 'is defined twice')
                    quit()
    # print(prefix)
    # print(species_data)

    # get list of reactions
    for e in listOfReactions:
        lb = None
        ub = None
        oc = None
        obj_fnct = False
        # define default values in case missing information
        default_lb = -1000
        default_ub = 1000
        default_oc = 0

        if e.tag[0] == "{":
            uri, tag = e.tag[1:].split("}")
        else:
            tag = e.tag
        if tag == "reaction":
            reactionId = e.attrib.get("id")

            # obtain list of parameters for linear programming part
            listOfParameters = get_listOfParameters(e)
            if listOfParameters == None:
                print("\n Error in reaction: ",reactionId, "listOfParameters = None")
                quit()
            for ee in listOfParameters:
                if ee.tag[0] == "{":
                    uri, tag = ee.tag[1:].split("}")
                else:
                    tag = ee.tag
                if tag == "parameter":
                    paramId = ee.attrib.get("id")
                    paramValue = ee.attrib.get("value")

                    if paramId == "LOWER_BOUND":
                        lb = int(paramValue)
                    elif paramId == "UPPER_BOUND":
                        ub = int(paramValue)
                    elif paramId == "OBJECTIVE_COEFFICIENT":
                        oc = int(paramValue)
                        if oc == 1:
                            objective_reactions.append(reactionId)
                            obj_fnct = True

            # check whether a parameter is found for lb, ub and oc, otherwise
            # set it to default value + tell user
            if lb == None:
                lb = default_lb
                print("Had to set lower bound to default value" + str(default_lb) + "for reaction " + reactionId)

            if ub == None:
                ub = default_ub
                print("Had to set upper bound to default value " + str(default_ub) + " for reaction " + reactionId)

            if (lb < 0 and ub > 0) or (lb > 0 and ub < 0):
                lpfacts.add(Term('reversible', ["\""+reactionId+"\""]))

            if oc == None:
                oc = default_oc
                print("Had to set objective coefficient to default value " + str(default_oc) + " for reaction " + reactionId)

            # make facts for an objective reaction
            if obj_fnct and prefix == 'd':
                lpfacts.add(Term('t_reaction', ["\""+reactionId+"\""]))
                lpfacts.add(Term('t_objective', ["\""+reactionId+"\"","\""+str(oc)+"\""]))
                lpfacts.add(Term('t_bounds', ["\""+reactionId+"\"","\""+str(lb)+"\"","\""+str(ub)+"\""]))

            # make facts for a regular reaction
            else:
                lpfacts.add(Term(prefix+'_reaction', ["\""+reactionId+"\""]))
                lpfacts.add(Term(prefix+'_objective', ["\""+reactionId+"\"","\""+str(oc)+"\""]))
                lpfacts.add(Term(prefix+'_bounds', ["\""+reactionId+"\"","\""+str(lb)+"\"","\""+str(ub)+"\""]))

            # get reactants of considered reactin
            listOfReactants = get_listOfReactants(e)
            # exit with error if no reactant for an objective function
            if listOfReactants== None and obj_fnct == True:
                print("\n error:",reactionId, "is the objective function and has no reactants")
                quit()
            # warn user if no reactants
            elif listOfReactants== None :
                print("\n Warning:",reactionId, "listOfReactants=None")
            # else make facts for each reactant
            else:
                for r in listOfReactants:
                    reactantId = r.attrib.get("species")
                    # define reactant diferently if reaction is objective function
                    if obj_fnct and prefix == 'd':
                        targets.append(reactantId)
                        lpfacts.add(Term('t_reactant', ["\""+reactantId+"\"","\""+r.attrib.get("stoichiometry")+"\"", "\""+reactionId+"\""]))
                    # else just add the reactant
                    else:
                        lpfacts.add(Term(prefix+'_reactant', ["\""+reactantId+"\"","\""+r.attrib.get("stoichiometry")+"\"", "\""+reactionId+"\""]))

                    # add the r_compound or d_compound if not already done for this compound
                    if not reactantId in added_species:
                        try:
                            lpfacts.add(Term(prefix+'_compound', ["\""+reactantId+"\"", "\""+species_data[reactantId]['compartment']+"\"", "\""+species_data[reactantId]['boundaryCondition']+"\""]))
                            added_species.append(reactantId)
                        except KeyError:
                            added_species.append(reactantId)
                            print(productId, reactionId)

            # get products of considered reaction
            listOfProducts = get_listOfProducts(e)
            # warn user if no products
            if listOfProducts== None :
                print("\n Warning:",reactionId, "listOfProducts=None")
            else:
                for p in listOfProducts:
                    productId = p.attrib.get("species")
                    # define product diferently if reaction is objective function
                    if obj_fnct and prefix == 'd':
                        lpfacts.add(Term('t_product', ["\""+productId+"\"", "\""+p.attrib.get("stoichiometry")+"\"", "\""+reactionId+"\""]))
                        lpfacts.add(Term('t_compound', ["\""+productId+"\"", "\""+p.attrib.get("stoichiometry")+"\"", "\""+reactionId+"\""]))
                        # add the t_compound
                        try:
                            lpfacts.add(Term('t_compound', ["\""+productId+"\"", "\""+species_data[productId]['compartment']+"\"", "\""+species_data[productId]['boundaryCondition']+"\""]))
                        except KeyError:
                            print('Error: product ' + productId + 'of the objective reaction '+ reactionId + ' is not defined in list of species')
                            quit()
                        # add it in added species if it was not already in ther
                        if not productId in added_species:
                            added_species.append(productId)
                    # else just add the product
                    else:
                        lpfacts.add(Term(prefix+'_product', ["\""+productId+"\"", "\""+p.attrib.get("stoichiometry")+"\"", "\""+reactionId+"\""]))
                        # add the r_compound or d_compound in the facts if not already done for this compound
                        if not productId in added_species:
                            try:
                                lpfacts.add(Term(prefix+'_compound', ["\""+productId+"\"", "\""+species_data[productId]['compartment']+"\"", "\""+species_data[productId]['boundaryCondition']+"\""]))
                                added_species.append(productId)
                            except KeyError:
                                added_species.append(productId)
                                print(productId, reactionId)


    #some checks to alert the user
    if prefix == "d":
        # no reaction has an objective coefficient 1
        if objective_reactions == []:
            print("\n Error in model: no defined objective function")
            quit()
        # several reactions have an objective reaction 1 : warn user, might not be wanted
        elif len(objective_reactions) > 1:
            print("\n Warning: > 1 objective reactions are defined " + str(objective_reactions))
        # no seeds are given
        if len(seeds) == 0:
            print("\n Error in model: no defined boundaryCondition = \"true\" species in ListOfSpecies. Please make the growth medium compounds at boundaryCondition = \"true\" ")
            quit()

    #check whether we added every compound (t_, r_, d_)
    if len(added_species) != len(species_data):
        if prefix =='d':
            print('DRAFT')
        else:
            print('REPAIR NETWORK')
        print('Warning: your list of species is not consistant with the list of reactants and products occurring in every reaction')
        extra_los = [x for x in species_data.keys() if not x in added_species]
        extra_reactant_or_product = [x for x in added_species if not x in species_data.keys()]
        if extra_los != [] :
            print('Compounds defined in listOfSpecies but not used in reactions: ' + str(extra_los))
        if extra_reactant_or_product != [] :
            print('Compounds defined as reactants or products in listOfReactions but not in listOfSpecies: ' + str(extra_reactant_or_product))
        print('This warning may lead to altered results during solving, you should correct it. \n')



    # print( "targets: " + str(targets))
    # print( "seeds: " + str(seeds))

    return lpfacts, seeds, targets



if __name__ == "__main__":

    parser = argparse.ArgumentParser()

    parser.add_argument('-d', '--draftnet',
                        help='metabolic network in SBML format', required=True)
    parser.add_argument('-r', '--repairnet',
                        help='perform network completion using REPAIRNET \
                        a metabolic network in SBML format')
    parser.add_argument('-o', '--output',
                        help='LP output: 2 files will be created \
                        <output>_draft.lp and <output>_repair.lp, \
                        please dont add the extension', required=True)


    args         = parser.parse_args()
    main(args)
