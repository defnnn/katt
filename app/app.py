import web_pdb
from flask import Flask, render_template

app = Flask(__name__)

greeting = "hello"

def hello(name):
    s = f"{greeting}, {name}!"
    print(s)
    return s


@app.route("/")
def serve():
    return render_template("index.html", greeting=greeting)


@app.route("/debug")
def debug():
    web_pdb.set_trace()
    return render_template("index.html", greeting=greeting)


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8000)
