"""Build stable vector tracks from the traced silhouettes for refresh-rate playback."""
from pathlib import Path
import json,re
import argparse
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--input", type=Path, default=ROOT / ".cache/traced-motion.js")
parser.add_argument("--output", type=Path, default=ROOT / "qml/HelloMotion.js")
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
source = args.input.read_text()
original=json.loads(source.split('var frames = ',1)[1].split(';',1)[0])
counts=[48,24,24,4,4,4,4]

def polygon(path):
    tokens=re.findall(r'[MLQCZ]|-?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',path)
    points=[];i=0;current=None;start=None
    while i<len(tokens):
        cmd=tokens[i];i+=1
        if cmd=='Z':
            if start is not None:points.append(start)
            continue
        n={'M':2,'L':2,'Q':4,'C':6}[cmd]
        values=np.array([float(v) for v in tokens[i:i+n]]).reshape((-1,2));i+=n
        if cmd=='M':current=values[0];start=current;points.append(current)
        elif cmd=='L':current=values[0];points.append(current)
        else:
            initial=current.copy()
            for t in np.linspace(0,1,17)[1:]:
                if cmd=='Q':point=(1-t)**2*initial+2*(1-t)*t*values[0]+t*t*values[1]
                else:point=(1-t)**3*initial+3*(1-t)**2*t*values[0]+3*(1-t)*t*t*values[1]+t**3*values[2]
                points.append(point)
            current=values[-1]
    return np.asarray(points)

def resample(points,n):
    if np.linalg.norm(points[-1]-points[0])>1e-5:points=np.vstack((points,points[0]))
    lengths=np.concatenate(([0.0],np.cumsum(np.linalg.norm(np.diff(points,axis=0),axis=1))))
    positions=np.arange(n)*lengths[-1]/n
    return np.column_stack([np.interp(positions,lengths,points[:,axis]) for axis in (0,1)])

def area(points):
    return abs(float(np.sum(points[:,0]*np.roll(points[:,1],-1)-points[:,1]*np.roll(points[:,0],-1)))/2)

tracks=[];previous=[None]*7
for index,parts in enumerate(original):
    assigned=[None]*7;face=[]
    for opacity,path in parts:
        points=polygon(path);center=points.mean(axis=0)
        if index>=116 and abs(center[0]-50)>28 and abs(center[1]-50)>28:
            slot=3+(1 if center[0]>50 else 0)+(2 if center[1]>50 else 0)
            minimum=points.min(axis=0);maximum=points.max(axis=0)
            x0,y0=minimum;x1,y1=maximum
            assigned[slot]=(opacity,np.array([[x0,y0],[x1,y0],[x1,y1],[x0,y1]]))
        else:face.append((area(points),opacity,points))
    if face:
        face.sort(key=lambda part:part[0],reverse=True)
        assigned[0]=(face[0][1],face[0][2])
        eyes=sorted(face[1:3],key=lambda part:part[2][:,0].mean())
        for eye_index,(_,opacity,points) in enumerate(eyes):
            if len(eyes)==1 and previous[1] is not None and previous[2] is not None:
                slot=min((1,2),key=lambda j:np.linalg.norm(points.mean(axis=0)-previous[j].mean(axis=0)))
            else:slot=eye_index+1
            assigned[slot]=(opacity,points)
    frame=[]
    for slot,part in enumerate(assigned):
        if part is None:frame.append(None);continue
        opacity,points=part
        points=resample(points,counts[slot]) if slot<3 else points
        if slot<3 and previous[slot] is not None:
            # Match corresponding contour points to avoid twists during interpolation.
            options=[np.roll(points,-shift,axis=0) for shift in range(len(points))]
            points=min(options,key=lambda value:float(np.sum((value-previous[slot])**2)))
        previous[slot]=points
        frame.append([opacity,points])
    tracks.append(frame)
# Missing shapes fade while retaining the most recent geometry. Before appearance,
# retain the first available pose so corner markers never travel from the center.
for slot in range(7):
    first=next((frame[slot][1] for frame in tracks if frame[slot] is not None),np.full((counts[slot],2),50.0))
    last=first
    for index,frame in enumerate(tracks):
        if frame[slot] is None:frame[slot]=[0.0,last]
        else:last=frame[slot][1]
        if index==0 and slot<3:frame[slot]=[0.0,np.full((counts[slot],2),50.0)]
frames=[[[round(opacity,3),np.round(points,3).ravel().tolist()] for opacity,points in frame] for frame in tracks]
header='''.pragma library
// Vector tracks reconstructed from the Windows Hello reference recording.
// Source: https://www.windowslatest.com/wp-content/uploads/2024/11/Windows-Hello-new-animation.gif
// Matched contour points are interpolated at the display refresh rate, not stepped at 25 fps.
var frameDuration = 40;
var loopStart = 800;
var loopEnd = 4600;
var successStart = 4600;
var successEnd = 6160;
'''
helper='''
function cubic(a, b, c, d, t) {
    return b + 0.5 * t * (c - a + t * (2*a - 5*b + 4*c - d + t * (3*(b-c) + d-a)));
}
function coordinate(n) { return String(Math.round(n * 100) / 100); }
function sample(time) {
    const position = Math.max(0, Math.min(frames.length - 1, time / frameDuration));
    const index = Math.floor(position), t = position - index;
    const a = frames[Math.max(0, index - 1)], b = frames[index];
    const c = frames[Math.min(frames.length - 1, index + 1)], d = frames[Math.min(frames.length - 1, index + 2)];
    const result = [];
    for (let slot = 0; slot < 7; ++slot) {
        const opacity = Math.max(0, Math.min(1, cubic(a[slot][0], b[slot][0], c[slot][0], d[slot][0], t)));
        if (opacity < 0.001) { result.push([0, ""]); continue; }
        const points = [];
        for (let i = 0; i < b[slot][1].length; ++i)
            points.push(cubic(a[slot][1][i], b[slot][1][i], c[slot][1][i], d[slot][1][i], t));
        let path;
        if (slot >= 3) {
            path = "M" + coordinate(points[0]) + "," + coordinate(points[1]);
            for (let i = 2; i < points.length; i += 2) path += " L" + coordinate(points[i]) + "," + coordinate(points[i+1]);
        } else {
            const length = points.length;
            path = "M" + coordinate((points[length-2]+points[0])/2) + "," + coordinate((points[length-1]+points[1])/2);
            for (let i = 0; i < length; i += 2) {
                const next = (i + 2) % length;
                path += " Q" + coordinate(points[i]) + "," + coordinate(points[i+1]) + " " +
                    coordinate((points[i]+points[next])/2) + "," + coordinate((points[i+1]+points[next+1])/2);
            }
        }
        result.push([opacity, path + " Z"]);
    }
    return result;
}
'''
args.output.write_text(header+'var frames = '+json.dumps(frames,separators=(',',':'))+';\n'+helper)
print(json.dumps({'frames':len(frames),'tracks':7,'bytes':args.output.stat().st_size}))
