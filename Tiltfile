# -*- mode: Python -*

k8s_yaml('tilt.yaml')
k8s_resource('katt', port_forwards=8000)

local_resource( 'deploy', 'python now.py > start-time.txt')

docker_build('defn/katt-image', '.', build_args={'flask_env': 'development'},
    live_update=[
        sync('now.py', '/app'),
        sync('app.py', '/app'),
        sync('requirements.txt', '/app'),
        sync('start-time.txt.txt', '/app'),
        sync('index.html', '/app'),

        run('cd /app && pip install -r requirements.txt', trigger='./requirements.txt'),
        run('touch /app/app.py', trigger='./start-time.txt'),

        run('sed -i "s/Hello katts!/{}/g" /app/templates/index.html'. format("Congrats, you ran a live update!")),
])
