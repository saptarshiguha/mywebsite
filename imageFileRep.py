from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive
import sys


from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive

gauth = GoogleAuth()
#Try to load saved client credentials
gauth.LoadCredentialsFile("mycreds.txt")
if gauth.credentials is None:
    # Authenticate if they're not there
    gauth.LocalWebserverAuth()
elif gauth.access_token_expired:
    # Refresh them if expired
    gauth.Refresh()
else:
    # Initialize the saved creds
    gauth.Authorize()
# Save the current credentials to a file
gauth.SaveCredentialsFile("mycreds.txt")



# ## http://stackoverflow.com/questions/24419188/automating-pydrive-verification-process
# gauth = GoogleAuth()
# gauth.LocalWebserverAuth()
drive = GoogleDrive(gauth) # Create GoogleDrive instance with authenticated GoogleAuth instance

allImages = []
allFolders = []
######################################################################
## Set folder name here
######################################################################
bp=sys.argv[1]  ### change this to get URL names for files in a particular folder
print("Using folder with name "+bp)


alist = drive.ListFile({'q': "title= '%s' "  % bp}).GetList()
def ListFolder(parent):
    file_list = drive.ListFile({'q': "'%s' in parents and trashed=false" % parent}).GetList()
    for f in file_list:
        print 'title: %s' % f['title']
        if f['mimeType']=='application/vnd.google-apps.folder': # if folder
            allFolders.append(f)
            ListFolder(f['id'])
        else:
            allImages.append(f)
ListFolder(alist[0]['id'])

d2 = {}
d2[alist[0]['id']]=[bp,"0"] 
for a in allFolders:
    pid = a['id']
    d2[pid] = [ a['title'], a['parents'][0]['id']]

f2 = []
for a in allImages:
    title = a['title']
    url = a[u'webContentLink']
    height = a[u'imageMediaMetadata']['height']
    width = a[u'imageMediaMetadata']['width']
    mod = a[u'modifiedDate'][0:10]
    pid = a['parents'][0]['id']
    f2.append(    [title, url] ) #, d2[pid][0],mod,width,height     ]  )

        
import csv
with open("/tmp/images.csv", 'wb') as csvfile:
    spamwriter = csv.writer(csvfile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
    heads = ['title','url'] #,'parent','moddate','w','h']
    spamwriter.writerow(heads)
    for r in  f2:
        spamwriter.writerow(r)
csvfile.close()
print("Lines written to /tmp/images.csv")
