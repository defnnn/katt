import web_pdb
from flask import Flask, render_template

app = Flask(__name__)


@app.route("/")
def serve():
    return render_template("index.html")


@app.route("/debug")
def debug():
    web_pdb.set_trace()
    return render_template("index.html")


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8000)
