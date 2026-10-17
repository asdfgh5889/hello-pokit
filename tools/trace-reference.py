"""Trace the recorded foreground into compact, themeable vector silhouettes.
Build-time reference analysis only; not a runtime dependency of the dialog.
"""
from pathlib import Path
from PIL import Image
import numpy as np
import json
import argparse

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--input", type=Path, default=ROOT / ".cache/reference/windows-hello.gif")
parser.add_argument("--output", type=Path, default=ROOT / ".cache/traced-motion.js")
args = parser.parse_args()
SOURCE, TARGET = args.input, args.output
TARGET.parent.mkdir(parents=True, exist_ok=True)


def rdp(points, tolerance=.65):
    if len(points)<3:return points
    p=np.asarray(points,dtype=float);line=p[-1]-p[0]
    norm=np.linalg.norm(line)
    distances=np.linalg.norm(p-p[0],axis=1) if norm==0 else np.abs(line[0]*(p[:,1]-p[0,1])-line[1]*(p[:,0]-p[0,0]))/norm
    i=int(distances.argmax())
    if distances[i]<=tolerance:return [points[0],points[-1]]
    return rdp(points[:i+1],tolerance)[:-1]+rdp(points[i:],tolerance)


def outline(points):
    pixels=set(points)
    source=np.asarray(points,dtype=float)
    minimum=source.min(axis=0);maximum=source.max(axis=0)+1
    density=len(points)/float(np.prod(maximum-minimum))
    def position(point):
        return round(50+(point[0]-331)*.42,2),round(50+(point[1]-187)*.42,2)
    def pair(point):
        x,y=position(point);return f'{x:g},{y:g}'
    if density>.84 and .8 < (maximum[0]-minimum[0])/(maximum[1]-minimum[1]) < 1.2:
        # The success tiles have genuinely square corners, not round silhouettes.
        x0,y0=minimum;x1,y1=maximum
        return f'M{pair((x0,y0))} L{pair((x1,y0))} L{pair((x1,y1))} L{pair((x0,y1))} Z'
    if density>.62:
        # Fit the eye ellipses, including perspective and the success wink.
        center=source.mean(axis=0)+.5
        covariance=np.cov(source.T,bias=True)
        values,vectors=np.linalg.eigh(covariance)
        matrix=2*vectors@np.diag(np.sqrt(np.maximum(values,0)))@vectors.T
        def eye(x,y):return pair(center+matrix@np.array([x,y]))
        k=.5522847498
        return (f'M{eye(1,0)} C{eye(1,k)} {eye(k,1)} {eye(0,1)} '
                f'C{eye(-k,1)} {eye(-1,k)} {eye(-1,0)} '
                f'C{eye(-1,-k)} {eye(-k,-1)} {eye(0,-1)} '
                f'C{eye(k,-1)} {eye(1,-k)} {eye(1,0)} Z')
    edges={}
    for x,y in pixels:
        if (x,y-1) not in pixels:edges.setdefault((x,y),[]).append((x+1,y))
        if (x+1,y) not in pixels:edges.setdefault((x+1,y),[]).append((x+1,y+1))
        if (x,y+1) not in pixels:edges.setdefault((x+1,y+1),[]).append((x,y+1))
        if (x-1,y) not in pixels:edges.setdefault((x,y+1),[]).append((x,y))
    loops=[]
    while edges:
        start=min(edges);point=start;loop=[];prev=(start[0]-1,start[1])
        for _ in range(10000):
            loop.append(point)
            candidates=edges.get(point)
            if not candidates:break
            dx,dy=point[0]-prev[0],point[1]-prev[1]
            preferred=[(-dy,dx),(dx,dy),(dy,-dx),(-dx,-dy)]
            candidate=min(candidates,key=lambda p:preferred.index((p[0]-point[0],p[1]-point[1])))
            candidates.remove(candidate)
            if not candidates:del edges[point]
            prev,point=point,candidate
            if point==start:break
        if len(loop)>4:loops.append(loop)
    # These foreground components have no intentional holes. Keep the exterior.
    if not loops:return ''
    loop=max(loops,key=len)
    # Remove GIF dithering before reconstructing smooth, antialiased vector curves.
    curve=np.asarray(loop,dtype=float)
    weights=np.array([1,3,6,7,6,3,1],dtype=float)/27
    curve=sum(weight*np.roll(curve,offset-3,axis=0) for offset,weight in enumerate(weights))
    loop=[tuple(point) for point in curve]
    split=max(range(len(loop)),key=lambda i:(loop[i][0]-loop[0][0])**2+(loop[i][1]-loop[0][1])**2)
    simple=rdp(loop[:split+1],.8)[:-1]+rdp(loop[split:]+[loop[0]],.8)[:-1]
    middle=lambda a,b:((a[0]+b[0])/2,(a[1]+b[1])/2)
    return 'M'+pair(middle(simple[-1],simple[0]))+' '+ ' '.join(
        'Q'+pair(point)+' '+pair(middle(point,simple[(i+1)%len(simple)]))
        for i,point in enumerate(simple))+' Z'


image=Image.open(SOURCE)
background=np.asarray(image.convert('RGB'),dtype=float)
frames=[]
vertex_count=0
for index in range(image.n_frames):
    image.seek(index)
    rgb=np.asarray(image.convert('RGB'),dtype=float)
    # White foreground over the recorded blue background, using the highest-contrast channel.
    alpha=np.clip((rgb[:,:,0]-background[:,:,0])/np.maximum(255-background[:,:,0],1),0,1)
    alpha[:60]=0;alpha[315:]=0;alpha[:,:195]=0;alpha[:,455:]=0
    peak=float(np.percentile(alpha[alpha>.15],99)) if np.any(alpha>.15) else 0
    mask=alpha>max(.16,peak*.45)
    components=[]
    for y,x in zip(*np.where(mask)):
        if not mask[y,x]:continue
        stack=[(int(x),int(y))];mask[y,x]=False;points=[]
        while stack:
            xx,yy=stack.pop();points.append((xx,yy))
            for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
                if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx]:
                    mask[ny,nx]=False;stack.append((nx,ny))
        if len(points)<14:continue
        opacity=round(float(np.percentile([alpha[yy,xx] for xx,yy in points],90)),3)
        path=outline(points)
        if path:
            vertex_count+=path.count('L')+1
            components.append([opacity,path])
    # Stable size order is sufficient: no geometry is interpolated between components.
    frames.append(sorted(components,key=lambda p:len(p[1]),reverse=True)[:8])
# End the traced geometry before the original Windows-logo morph.
frames=frames[:141]
header='''.pragma library
// Vector tracing of the Windows Hello recording, not an original Microsoft animation asset.
// Source: https://www.windowslatest.com/wp-content/uploads/2024/11/Windows-Hello-new-animation.gif
// Geometry reconstructed from recorded silhouettes at 25 fps, normalized to a 100x100 view.
// No raster frames, background imagery, or Windows runtime code are used at runtime.
var frameDuration = 40;
var loopStart = 800;
var loopEnd = 4600;
var successStart = 4600;
var successEnd = 6160;
'''
TARGET.write_text(header+'var frames = '+json.dumps(frames,separators=(',',':'))+';\n')
print(json.dumps({'frames':len(frames),'vertices':vertex_count,'bytes':TARGET.stat().st_size,'max_parts':max(map(len,frames))}))
