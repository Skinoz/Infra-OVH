<!DOCTYPE html>
<html>
<head>
    <title>Web Server ${server_number}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            text-align: center;
            background: white;
            padding: 50px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
        }
        h1 { color: #333; margin: 0 0 20px 0; }
        p { color: #666; font-size: 18px; }
        .server-number {
            font-size: 72px;
            font-weight: bold;
            color: #667eea;
        }
    </style>
</head>
<body>
    <div class='container'>
        <div class='server-number'>${server_number}</div>
        <h1>🚀 Web Server ${server_number}</h1>
        <p>Serveur web Nginx configuré avec Packer</p>
        <p>Image créée pour OVH Public Cloud</p>
        <p><small>Version: ${version}</small></p>
    </div>
</body>
</html>