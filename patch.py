import os
import glob

directory = r'c:\Users\shese\showsnap\lib\features\admin\screens'
files = glob.glob(os.path.join(directory, '*.dart'))

sign_out_method = '''
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await StaffConfirmDialog.show(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDangerous: true,
    );
    if (ok == true && context.mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }
'''

import_statement = "import '../../auth/providers/auth_provider.dart';"

for file in files:
    if 'admin_dashboard_screen.dart' in file or 'add_theater_screen.dart' in file:
        continue
        
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
        
    if 'onSignOut: () {},' in content:
        # Add import
        if import_statement not in content:
            lines = content.split('\n')
            last_import_idx = 0
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    last_import_idx = i
            lines.insert(last_import_idx + 1, import_statement)
            content = '\n'.join(lines)
            
        # replace onSignOut
        content = content.replace('onSignOut: () {},', 'onSignOut: () => _signOut(context, ref),')
        
        # add _signOut method before build
        build_idx = content.find('  @override\n  Widget build(BuildContext context')
        if build_idx == -1:
            build_idx = content.find('  Widget build(BuildContext context')
            
        if build_idx != -1:
            content = content[:build_idx] + sign_out_method + '\n' + content[build_idx:]
            
        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f'Updated {os.path.basename(file)}')
