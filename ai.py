'''
This is adapted from Batchu Venkat Vishal's Flappy Bird Genetic Algorithm project

--

MIT License

Copyright (c) 2017 Batchu Venkat Vishal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'''

import math
import numpy as np
from keras.models import Sequential
from keras.layers import Dense, Activation
from keras.optimizers import SGD
import random

load_saved_pool = 0
save_current_pool = 1
current_pool = []
fitness = []
total_models = 100
generation = 1

def save_pool():
    for xi in range(total_models):
        current_pool[xi].save_weights("Current_Model_Pool/model_new" + str(xi) + ".keras")
    print("Saved current pool!")

def model_crossover(model_idx1, model_idx2):
    global current_pool
    weights1 = current_pool[model_idx1].get_weights()
    weights2 = current_pool[model_idx2].get_weights()
    weightsnew1 = weights1
    weightsnew2 = weights2
    weightsnew1[0] = weights2[0]
    weightsnew2[0] = weights1[0]
    return np.asarray([weightsnew1, weightsnew2])

def model_mutate(weights):
    for xi in range(len(weights)):
        for yi in range(len(weights[xi])):
            if random.uniform(0, 1) > 0.75: # if random.uniform(0, 1) > 0.85:
                change = random.uniform(-1.5,1.5) # change = random.uniform(-0.5,0.5)
                weights[xi][yi] += change
    return weights

# Initialize all models
for i in range(total_models):
    model = Sequential()
    model.add(Dense(output_dim=100, input_dim=258))
    model.add(Activation("sigmoid"))
    # Outputs: up, down, left, right, L, A, B, Y
    model.add(Dense(output_dim=8))
    model.add(Activation("sigmoid"))

    sgd = SGD(lr=0.01, decay=1e-6, momentum=0.9, nesterov=True)
    model.compile(loss="mse", optimizer=sgd, metrics=["accuracy"])
    current_pool.append(model)
    fitness.append(-100)

if load_saved_pool:
    for i in range(total_models):
        current_pool[i].load_weights("Current_Model_Pool/model_new"+str(i)+".keras")

def adjust_inputs(outfile):
    global current_pool
    data = []
    s = outfile.readline()
    index = 1
    while s != '':
        num = float(s)
        if index > 255:
            data.append(num)
        elif index > 7:
            data.append((num + 2) / 4)
        elif index == 1: # boosted
            data.append(1 if (num == 58) else 0)
        elif index == 2: # shrunk
            data.append(1 if (num == 128) else 0)
        elif index == 3: # coins
            data.append(num / 255)
        elif index == 4: # jump height
            data.append(num / 65535)
        elif index == 5: # mole / gopher
            data.append(0 if (num == 0) else 1)
        elif index == 6: # kart status
            data.append(1 if (num == 0) else 0)
            data.append(1 if (num == 2) else 0)
            data.append(1 if (num == 4) else 0)
            data.append(1 if (num == 6) else 0)
            data.append(1 if (num == 8) else 0)
        else: # collision
            data.append(num / 7)

        s = outfile.readline()
        index += 1
    return data

buttons = ("up", "down", "left", "right", "L", "A", "B", "Y")
def run_network(network, outfile):
    global current_pool
    neural_input = np.asarray(adjust_inputs(outfile))
    neural_input = np.atleast_2d(neural_input)
    outputs = current_pool[network].predict(neural_input, 1)[0]
    infile = open("in", "w")
    outputted = False
    for i in range(0, len(buttons)):
        if outputs[i] >= 0.5:
            outputted = True
            infile.write("P" + buttons[i] + "\n")
    if not outputted:
        infile.write("I\n")
    infile.close()

def norm(x, y):
    return math.sqrt(x*x + y*y)

def test_network(network):
    frame = -1 # frame counter
    lap = 0
    lakitu = 0 # counts number of ticks during which we're backwards
    score = 0
    posx = 0
    posy = 0
    lap = 0

    # reset
    infile = open("in", "w")
    infile.write("R\n")
    infile.close()
    # detect when we're back up by emptying this file and waiting for it not to be empty
    outfile = open("out", "w")
    outfile.close()
    print("Ready to start network " + str(network) + " of generation " + str(generation))

    while True:
        outfile = open("out", "r")
        current_frame = outfile.readline()
        if current_frame != '' and int(current_frame) != frame:
            if frame == 0:
                print("Starting")
            frame = int(current_frame)
            lakitu_flag = int(outfile.readline())
            speed = int(outfile.readline())
            newposx = int(outfile.readline())
            newposy = int(outfile.readline())
            lap = int(outfile.readline()) - 127

            score = score * (frame / 4) / (frame / 4 + 1) + speed / (frame / 4 + 1)

            if lap == 6:
                # success
                print("Won race")
                score += 7000 + 36000000 / frame
                break

            if lakitu_flag == 1:
                lakitu += 1
            else:
                lakitu = 0

            resetflag = False
            if frame % 600 == 0:
                if frame != 0 and norm(posx - newposx, posy - newposy) < 100:
                    resetflag = True
                posx = newposx
                posy = newposy
            if resetflag or lakitu > 5 or frame >= 36000:
                # fail
                print("Got stuck")
                score += lap * 1000 + frame / 36
                break

            run_network(network, outfile)
        outfile.close()
    return score

for i in range(0, 100000):
    for i in range(0, total_models):
        score = test_network(i)
        print("Score: " + str(score) + "\n")
        fitness[i] = score
    """Perform genetic updates here"""
    new_weights = []
    total_fitness = 0
    for select in range(total_models):
        total_fitness += fitness[select]
    for select in range(total_models):
        fitness[select] /= total_fitness
        if select > 0:
            fitness[select] += fitness[select-1]
    for select in range(int(total_models/2)):
        parent1 = random.uniform(0, 1)
        parent2 = random.uniform(0, 1)
        idx1 = -1
        idx2 = -1
        for idxx in range(total_models):
            if fitness[idxx] >= parent1:
                idx1 = idxx
                break
        for idxx in range(total_models):
            if fitness[idxx] >= parent2:
                idx2 = idxx
                break
        new_weights1 = model_crossover(idx1, idx2)
        updated_weights1 = model_mutate(new_weights1[0])
        updated_weights2 = model_mutate(new_weights1[1])
        new_weights.append(updated_weights1)
        new_weights.append(updated_weights2)
    for select in range(len(new_weights)):
        fitness[select] = -100
        current_pool[select].set_weights(new_weights[select])
    if save_current_pool == 1:
        save_pool()
    generation = generation + 1

infile = open("in", "w")
infile.write("W\n")
infile.close()
