# -*- mode: Python -*

k8s_yaml('tilt.yaml')
k8s_resource('katt', port_forwards=8000)

local_resource( 'deploy', 'python now.py > start-time.txt')

docker_build('defn/katt-image', '.', build_args={'flask_env': 'development'},
    live_update=[
        sync('now.py', '/app/now.py'),
        sync('app.py', '/app/app.py'),
        sync('requirements.txt', '/app/requirements.txt'),
        sync('start-time.txt', '/app/start-time.txt'),
        sync('index.html', '/app/templates/index.html'),
        sync('pets.png', '/app/static/pets.png'),

        run('cd /app && pip install -r requirements.txt', trigger='./requirements.txt'),
        run('touch /app/app.py', trigger='./start-time.txt'),

        run('sed -i "s/Hello cats!/{}/g" /app/templates/index.html'. format("Congrats, you ran a live update!")),
])
