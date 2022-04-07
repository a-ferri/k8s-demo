from cmath import sqrt
from flask import Flask
from random import randint

app = Flask(__name__)


@app.route('/')
def home():
    n = randint(100, 10000)
    r = sqrt(n)
    return f'Square root of {n} is {r}'