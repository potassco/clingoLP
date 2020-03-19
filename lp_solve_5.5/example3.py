from numpy import *
from numpy.linalg import inv
x = dot(inv(array([[1, 1], [110, 30]])), array([75, 4000]))
print( x)
P = dot(array([143, 60]), x)
print (P)