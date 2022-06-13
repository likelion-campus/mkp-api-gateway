from flask import Flask, jsonify

app = Flask(__name__)


@app.route('/oauth/token/introspect', methods=["POST", ])
def token_introspect():
    return jsonify({
        "sub": 1,
        "active": True,
        "account-addresses": "1|0x110943,3|0x663993",
        "current-address": "1|0x110943",
    })
